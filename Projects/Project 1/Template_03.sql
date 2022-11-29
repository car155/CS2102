CREATE TABLE Users (
  email VARCHAR(50),
  name  VARCHAR(50) NOT NULL,
  cc1 VARCHAR(16) NOT NULL,
  cc2 VARCHAR(16),
  PRIMARY KEY (email)
);

CREATE TABLE Creators (
  email VARCHAR(50),
  country VARCHAR(50) NOT NULL,
  PRIMARY KEY (email),
  FOREIGN KEY (email) REFERENCES Users(email) ON DELETE CASCADE
);

CREATE TABLE Backers (
  email VARCHAR(50),
  street VARCHAR(50) NOT NULL,
  house_no INTEGER NOT NULL,
  zip INTEGER NOT NULL,
  country VARCHAR(50) NOT NULL,
  PRIMARY KEY (email),
  FOREIGN KEY (email) REFERENCES Users(email) ON DELETE CASCADE
);

CREATE TABLE Projects (
  id       SERIAL,
  name     VARCHAR(50) NOT NULL,
  goal     MONEY NOT NULL,
  deadline DATE NOT NULL,
  creator_id VARCHAR(50) NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (creator_id) REFERENCES Creators(email)
);

CREATE TABLE Updates (
  id SERIAL,
  time TIMESTAMP,
  PRIMARY KEY (id, time),
  FOREIGN KEY (id) REFERENCES Projects(id) ON DELETE CASCADE ON UPDATE CASCADE,
);

CREATE TABLE Employees (
  id     SERIAL,
  name   VARCHAR(50) NOT NULL,
  salary MONEY NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE Verifies (
  user_id VARCHAR(50),
  employee_id SERIAL NOT NULL,
  date DATE NOT NULL,
  PRIMARY KEY (user_id),
  FOREIGN KEY (user_id) REFERENCES Users(email),
  FOREIGN KEY (employee_id) REFERENCES Employees(id)
);

CREATE TABLE RefundRequest (
  project_id SERIAL,
  backer_id VARCHAR(50),
  employee_id SERIAL,
  submission_date DATE NOT NULL,
  processed_date  DATE,
  status INTEGER,
  PRIMARY KEY (project_id, backer_id),
  FOREIGN KEY (project_id) REFERENCES Projects(id),
  FOREIGN KEY (backer_id) REFERENCES Backers(email),
  FOREIGN KEY (employee_id) REFERENCES Employees(id)
);

CREATE TABLE ProjectRewardLevel (
  project_id SERIAL,
  name       VARCHAR(50),
  min_amount MONEY NOT NULL,
  PRIMARY KEY (project_id, name),
  FOREIGN KEY (project_id) REFERENCES Projects(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Funds (
  project_id SERIAL,
  backer_id VARCHAR(50),
  level_name VARCHAR(50) NOT NULL,
  amount MONEY NOT NULL,
  PRIMARY KEY (project_id, backer_id),
  FOREIGN KEY (project_id) REFERENCES Project(id),
  FOREIGN KEY (backer_id) REFERENCES Backers(email),
  FOREIGN KEY (level_name) REFERENCES ProjectRewardLevel(name)
);

