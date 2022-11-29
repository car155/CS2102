------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- CS2102 - ASSIGNMENT 1 (SQL)
--
------------------------------------------------------------------------
------------------------------------------------------------------------



DROP VIEW IF EXISTS student, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10;



------------------------------------------------------------------------
-- Replace the dummy values without Student ID & NUSNET ID
------------------------------------------------------------------------


CREATE OR REPLACE VIEW student(student_id, nusnet_id) AS
 SELECT 'A0205190R', 'e0425113'
;






------------------------------------------------------------------------
-- Query Q1
------------------------------------------------------------------------

CREATE OR REPLACE VIEW v1 (area, num_stations) AS
    SELECT sz.area, COUNT(*)
    FROM mrt_stations mrt, subzones sz
    WHERE mrt.subzone = sz.name
    GROUP BY sz.area
    HAVING COUNT(*) >= 5
;





------------------------------------------------------------------------
-- Query Q2
------------------------------------------------------------------------

CREATE OR REPLACE VIEW v2 (number, street, distance) AS
    SELECT DISTINCT number, street, ROUND(geodistance(lat, lng, 1.29271, 103.7754), 2) AS distance
    FROM hdb_blocks, hdb_has_units
    WHERE block_id = id 
        AND unit_type = '1room'
    ORDER BY distance ASC
    LIMIT 10
;





------------------------------------------------------------------------
-- Query 3
------------------------------------------------------------------------

CREATE OR REPLACE VIEW v3 (area, num_blocks) AS
    WITH area_has_hdb AS
        (SELECT *
        FROM subzones sz, hdb_blocks hdb
        WHERE sz.name = hdb.subzone)
    SELECT a.name, COUNT(id)
    FROM areas a LEFT JOIN area_has_hdb hdb
        ON a.name = hdb.area
    GROUP BY a.name
    ORDER BY COUNT(id) DESC
;




------------------------------------------------------------------------
-- Query Q4
------------------------------------------------------------------------

CREATE OR REPLACE VIEW v4 (area) AS
    WITH mrt_with_area_name AS
        (SELECT mrt.name, mrt.subzone
        FROM mrt_stations mrt, areas a
        WHERE mrt.name = a.name)
    SELECT DISTINCT mrta.name
    FROM mrt_with_area_name AS mrta, subzones sz
    WHERE mrta.subzone = sz.name
        AND mrta.name <> sz.area
;




------------------------------------------------------------------------
-- Query Q5
------------------------------------------------------------------------

CREATE OR REPLACE VIEW v5 (mrt_station, num_blocks) AS
    WITH ew_mrt_stations AS
        (SELECT name, lat, lng
        FROM mrt_stations, mrt_stops
        WHERE name = station
            AND line = 'ew')
    SELECT mrt.name, COUNT(*)
    FROM ew_mrt_stations mrt, hdb_blocks hdb
    WHERE geodistance(mrt.lat, mrt.lng, hdb.lat, hdb.lng) <= 0.3
    GROUP BY mrt.name
    ORDER BY COUNT(*) DESC
    LIMIT 5
;





------------------------------------------------------------------------
-- Query Q6
------------------------------------------------------------------------

CREATE OR REPLACE VIEW v6 (subzone) AS
    WITH subzones_with_1room_hdb AS
        (SELECT *
        FROM hdb_has_units, hdb_blocks
        WHERE block_id = id
            AND unit_type = '1room')
    SELECT subzone
    FROM hdb_blocks
    EXCEPT
    SELECT subzone
    FROM subzones_with_1room_hdb
;




------------------------------------------------------------------------
-- Query Q7
------------------------------------------------------------------------

CREATE OR REPLACE VIEW v7 (mrt_station) AS
    WITH connection_same_line AS
        (SELECT c.from_code, c.to_code, f.station, f.line
        FROM mrt_connections c, mrt_stops f, mrt_stops t
        WHERE c.from_code = f.code
            AND c.to_code = t.code
            AND f.line = t.line),
        end_station_codes AS
        (SELECT to_code
        FROM connection_same_line
        GROUP BY line, to_code
        HAVING COUNT(*) = 1)
    SELECT DISTINCT station
    FROM end_station_codes, mrt_stops
    WHERE to_code = code
;





------------------------------------------------------------------------
-- Query Q8
------------------------------------------------------------------------

CREATE OR REPLACE VIEW v8 (mrt_station, num_stops) AS
    WITH RECURSIVE mrt_path AS
        (SELECT from_code, to_code, 1 AS stops
        FROM mrt_connections
        WHERE to_code = 'cc24'
        UNION ALL
        SELECT c.from_code, p.to_code, p.stops+1
        FROM mrt_path p, mrt_connections c
        WHERE p.from_code = c.to_code
            AND p.to_code <> c.from_code
        AND p.stops < 10)
    SELECT station, MIN(stops) AS stops
    FROM mrt_path, mrt_stops
    WHERE from_code = code
    GROUP BY station
    ORDER BY stops ASC
;





------------------------------------------------------------------------
-- Query Q9
------------------------------------------------------------------------

CREATE OR REPLACE VIEW v9 (subzone, num_blocks) AS
    WITH earliest_opened_dt_subzone AS
        (SELECT subzone, MIN(opened) AS opened
        FROM mrt_stations, mrt_stops
        WHERE name = station
            AND line = 'dt'
        GROUP BY subzone),
        hdb_built_after_dt_subzone AS
        (SELECT sz.subzone, hdb.id, sz.opened, hdb.completed
        FROM earliest_opened_dt_subzone sz, hdb_blocks hdb
        WHERE sz.subzone = hdb.subzone
            AND sz.opened <= hdb.completed)
    SELECT sz.subzone, COUNT(id)
    FROM earliest_opened_dt_subzone sz LEFT JOIN hdb_built_after_dt_subzone hdb
        ON sz.subzone = hdb.subzone
    GROUP BY sz.subzone
;






------------------------------------------------------------------------
-- Query Q10
------------------------------------------------------------------------

CREATE OR REPLACE VIEW v10 (stop_code) AS
    WITH all_code AS
        (SELECT line, GENERATE_SERIES(1, 
            MAX(CAST(SUBSTRING(code, 3) AS INTEGER))) AS num
        FROM mrt_stops
        GROUP BY line)
    SELECT CONCAT(line, num)
    FROM all_code
    EXCEPT
    SELECT code
    FROM mrt_stops
;


