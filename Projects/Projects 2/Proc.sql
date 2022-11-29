/* ----- TRIGGERS     ----- */
/* Trigger #1 */
CREATE OR REPLACE FUNCTION validate_user()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM Backers b WHERE b.email = NEW.email) AND NOT EXISTS (SELECT 1 FROM Creators c WHERE c.email = NEW.email) THEN
    RAISE EXCEPTION 'User is not a backer or creator';
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER valid_user
AFTER INSERT ON Users
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION validate_user();



/* Trigger #2 */
CREATE OR REPLACE FUNCTION min_pledge_check()
RETURNS TRIGGER AS $$
DECLARE
	min_amount NUMERIC;
BEGIN
	SELECT min_amt INTO min_amount
    	FROM rewards WHERE name = new.name AND id = new.id;
 
	IF (new.amount >= min_amount) THEN
    		RETURN new;
	ELSE
    		RAISE EXCEPTION 'Minimum Reward level not met';
	END IF;
END;
$$ language plpgsql;
 
CREATE TRIGGER pledge_checker
	BEFORE INSERT ON backs
	FOR EACH ROW EXECUTE FUNCTION min_pledge_check();



/* Trigger #3 */
CREATE OR REPLACE FUNCTION check_project_has_level()
RETURNS TRIGGER AS $$ 
BEGIN
  IF NOT EXISTS (SELECT id FROM Rewards WHERE id = NEW.id) THEN
    RAISE 'Project has no reward levels';
  END IF; 
  RETURN NULL;
END; $$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER project_has_level_check
AFTER INSERT ON Projects 
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_project_has_level();



/* Trigger #4 */
CREATE OR REPLACE FUNCTION check_refund_request()
RETURNS TRIGGER AS $$
DECLARE
  rrdate DATE;
  pdeadline DATE;
BEGIN
  SELECT request INTO rrdate
  FROM Backs
  WHERE NEW.email = Backs.email AND NEW.pid = Backs.id;
 
  IF rrdate IS NULL THEN
    RAISE EXCEPTION 'Refund not requested!';
  END IF;
 
  SELECT deadline INTO pdeadline
  FROM Projects
  WHERE NEW.pid = Projects.id;
 
  IF pdeadline + INTERVAL '90 days' < rrdate AND NEW.accepted = TRUE THEN 
    RAISE EXCEPTION 'Cannot accept refund requested 90 days after project deadline!';
  ELSE
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;
 
CREATE TRIGGER enforce_refund
BEFORE INSERT ON Refunds
FOR EACH ROW EXECUTE FUNCTION check_refund_request();



/* Trigger #5 */
CREATE OR REPLACE FUNCTION check_backing_day()
RETURNS TRIGGER AS $$
DECLARE
  pcreation_date DATE;
  pdeadline DATE;
BEGIN
  SELECT created, deadline INTO pcreation_date, pdeadline
  FROM Projects
  WHERE NEW.id = Projects.id;
 
  IF NEW.backing <= pdeadline AND NEW.backing >= pcreation_date THEN 
    RETURN NEW;
  ELSE
    RAISE EXCEPTION 'Must back before deadline and after creation!';
  END IF;
END;
$$ LANGUAGE plpgsql;
 
CREATE TRIGGER back_after_creation_before_deadline
BEFORE INSERT ON Backs
FOR EACH ROW EXECUTE FUNCTION check_backing_day();



/* Trigger #6 */
CREATE OR REPLACE FUNCTION can_request()
RETURNS TRIGGER AS $$
DECLARE
  pmoney_pledged NUMERIC;
  pdeadline DATE;
  pgoal NUMERIC;
BEGIN
  SELECT deadline, goal INTO pdeadline, pgoal
  FROM Projects
  WHERE NEW.id = Projects.id;
 
  SELECT COALESCE(SUM(amount), 0) INTO pmoney_pledged
  FROM Backs
  WHERE NEW.id = Backs.id;
 
  IF pdeadline < CURRENT_DATE AND pgoal <= pmoney_pledged THEN 
    RETURN NEW;
  ELSE
    RAISE EXCEPTION 'Can only request refund for successful project!';
  END IF;
END;
$$ LANGUAGE plpgsql;
 
CREATE TRIGGER request_refund_on_successful_request_only
BEFORE UPDATE ON Backs
FOR EACH ROW WHEN (OLD.request IS NULL AND NEW.request IS NOT NULL) EXECUTE FUNCTION can_request();

/* ------------------------ */





/* ----- PROECEDURES  ----- */
/* Procedure #1 */
CREATE OR REPLACE PROCEDURE add_user(
  email TEXT, name    TEXT, cc1  TEXT,
  cc2   TEXT, street  TEXT, num  TEXT,
  zip   TEXT, country TEXT, kind TEXT
) AS $$
DECLARE
  is_backer BOOLEAN;
  is_creator BOOLEAN;
  is_none BOOLEAN;
BEGIN
    INSERT INTO Users VALUES (email, name, cc1, cc2);

    is_backer := kind = 'BACKER' OR kind = 'BOTH';
    is_creator := kind = 'CREATOR' OR kind = 'BOTH';
    is_none := NOT (is_backer OR is_creator);

    IF is_none THEN
      RAISE EXCEPTION 'Invalid user kind';
    END IF;

    IF is_backer THEN
      INSERT INTO Backers VALUES (email, street, num, zip, country);
    END IF;

    IF is_creator THEN
      INSERT INTO Creators VALUES (email, country);
    END IF;
END;
$$ LANGUAGE plpgsql;



/* Procedure #2 */
CREATE OR REPLACE PROCEDURE add_project(
  id  	INT, 	email TEXT,   ptype	TEXT,
  created DATE,	name  TEXT,   deadline DATE,
  goal	NUMERIC, names TEXT[],
  amounts NUMERIC[]
) AS $$
DECLARE
	num_reward_levels INT;
	num_amounts INT;
BEGIN
	SELECT cardinality(names) INTO num_reward_levels;
	SELECT cardinality(amounts) INTO num_amounts;

	IF (num_reward_levels = num_amounts) THEN
    	INSERT INTO projects VALUES (add_project.id, add_project.email, add_project.ptype, add_project.created, add_project.name, add_project.deadline, add_project.goal);
    	FOR index IN 1..(num_reward_levels) LOOP
        	INSERT INTO rewards VALUES (names[index], add_project.id, amounts[index]);
    	END LOOP;
    	END IF;
END;
$$ LANGUAGE plpgsql;



/* Procedure #3 */
CREATE OR REPLACE PROCEDURE auto_reject(
  eid INT, today DATE
) AS $$
DECLARE
  -- select all backing that requests a refund and the refund has not been accepted/rejected
  curs CURSOR FOR (SELECT * FROM Backs WHERE request IS NOT NULL 
    AND NOT EXISTS 
      (SELECT * FROM Refunds WHERE Backs.email = email AND Backs.id = pid));
  r RECORD;
  deadline DATE;
BEGIN
  OPEN curs;
  LOOP
    FETCH curs INTO r;
    EXIT WHEN NOT FOUND;
    SELECT Projects.deadline INTO deadline FROM Projects WHERE id = r.id;

    IF deadline + INTERVAL '90 days' < r.request THEN
      INSERT INTO Refunds VALUES (r.email, r.id, eid, today, FALSE);
    END IF;
  END LOOP;
  CLOSE curs;
END;
$$ LANGUAGE plpgsql;

/* ------------------------ */





/* ----- FUNCTIONS    ----- */
/* Function #1  */
CREATE OR REPLACE FUNCTION find_successful_projects_on(
  today DATE
) RETURNS TABLE(id INT, ptype TEXT) AS $$
BEGIN
  RETURN QUERY SELECT p.id, p.ptype FROM Projects p
  JOIN Backs b ON b.id = p.id
  WHERE p.deadline <= today AND today <= p.deadline + INTERVAL '30 days'
  GROUP BY p.id
  HAVING sum(b.amount) >= p.goal;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION find_successful_projects_backed_by(
  today DATE, email_ TEXT
) RETURNS TABLE(id INT, ptype TEXT, amount NUMERIC) AS $$
BEGIN
  RETURN QUERY SELECT p.id, p.ptype, b.amount FROM find_successful_projects_on(today) p, Backs b
  WHERE p.id = b.id AND b.email = email_;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION find_superbackers(
  today DATE
) RETURNS TABLE(email_ TEXT, name_ TEXT) AS $$
DECLARE
  backer RECORD;

  criteria_one BOOLEAN := FALSE;
  at_least_5_projects BOOLEAN;
  at_least_3_types BOOLEAN;

  criteria_two BOOLEAN := FALSE;
  at_least_1500_sgd BOOLEAN;
  no_refunds BOOLEAN;
BEGIN
  FOR backer IN
    SELECT b.email, u.name FROM Backers b, Users u, Verifies v
    WHERE b.email = u.email AND b.email = v.email AND v.verified <= today
    ORDER BY b.email ASC
  LOOP
    email_ := backer.email;
    name_ := backer.name;

    at_least_5_projects := (SELECT COUNT(id) FROM find_successful_projects_backed_by(today, email_)) >= 5;
    at_least_3_types := (SELECT COUNT(DISTINCT ptype) FROM find_successful_projects_backed_by(today, email_)) >= 3;
    criteria_one := at_least_5_projects AND at_least_3_types;

    at_least_1500_sgd := (SELECT sum(amount) FROM find_successful_projects_backed_by(today, email_)) >= 1500;
    no_refunds := NOT EXISTS (SELECT 1 FROM Backs WHERE email = email_ AND request <= today + INTERVAL '30 days');
    criteria_two := at_least_1500_sgd AND no_refunds;

    IF criteria_one OR criteria_two THEN
      RETURN NEXT;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;



/* Function #2  */
CREATE OR REPLACE FUNCTION find_top_success(
  n INT, today DATE, projtype TEXT
) RETURNS TABLE(id INT, name TEXT, email TEXT,
            	amount NUMERIC) AS $$
	-- Compute the amount
	-- Filter projects deadline before given date and same proj type
	-- Order them
	WITH TotalFunds AS
    	(SELECT backs.id AS fundsId, sum(backs.amount) AS fundsTotal
        	FROM backs
        	GROUP BY backs.id),
	ValidProjects AS
    	(SELECT projects.id AS validId, projects.name AS validName, projects.email AS validEmail, projects.deadline AS validDeadline, fundsTotal AS validTotal, fundsTotal/projects.goal AS validRatio
        	FROM projects INNER JOIN TotalFunds
            	ON projects.id = fundsId
        	WHERE projects.deadline < today AND projects.ptype = projtype
        	ORDER BY validRatio DESC, validDeadline DESC, validId
        	LIMIT n)
	SELECT validId AS id, validName AS name, validEmail AS email, validTotal AS amount
	FROM ValidProjects
$$ LANGUAGE sql;



/* Function #3  */
CREATE OR REPLACE FUNCTION get_goal_reach_days(pid INT)
  RETURNS INT AS $$
DECLARE
  curs CURSOR FOR (SELECT * FROM Backs WHERE Backs.id = pid ORDER BY backing ASC);   r RECORD; 
  cum_sum INT;
  goal INT;
  start_date DATE;
BEGIN
  cum_sum := 0;
  SELECT Projects.goal INTO goal FROM Projects WHERE Projects.id = pid;
  SELECT Projects.created INTO start_date FROM Projects WHERE Projects.id = pid;
  OPEN curs;
  LOOP
    FETCH curs INTO r;
    EXIT WHEN NOT FOUND;
    cum_sum := cum_sum + r.amount;
    IF cum_sum >= goal THEN
      CLOSE curs;
      RETURN r.backing - start_date;
    END IF;

  END LOOP;
  CLOSE curs;
  RETURN NULL;   
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION find_top_popular(
  n INT, today DATE, type TEXT
) RETURNS TABLE(id INT, name TEXT, email TEXT,
                days INT) AS $$
BEGIN
  RETURN QUERY SELECT p.id, p.name, p.email, get_goal_reach_days(p.id) days 
    -- rename columns to prevent ambiguity
                FROM Projects p 
                WHERE get_goal_reach_days(p.id) IS NOT NULL 
                  AND p.created < today 
                  AND p.ptype = type
                ORDER BY days ASC, id ASC
                LIMIT n;
END;
$$ LANGUAGE plpgsql;

/* ------------------------ */