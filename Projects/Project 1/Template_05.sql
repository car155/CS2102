CREATE TABLE Users (
  email TEXT, /* Change to text */
  name  TEXT NOT NULL,
  cc1 VARCHAR(16) NOT NULL,
  cc2 VARCHAR(16),
  PRIMARY KEY (email)
);

CREATE TABLE Creators (
  email TEXT,
  country TEXT NOT NULL,
  PRIMARY KEY (email),
  FOREIGN KEY (email) REFERENCES Users(email) ON DELETE CASCADE
);

CREATE TABLE Backers (
  email TEXT,
  street TEXT NOT NULL,
  house_no INTEGER NOT NULL,
  zip INTEGER NOT NULL,
  country TEXT NOT NULL,
  PRIMARY KEY (email),
  FOREIGN KEY (email) REFERENCES Users(email) ON DELETE CASCADE
);

CREATE TABLE Projects (
  id       SERIAL,
  name     TEXT NOT NULL,
  goal     MONEY NOT NULL,
  deadline DATE NOT NULL,
  creation_date DATE NOT NULL,
  creator_id TEXT NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (creator_id) REFERENCES Creators(email)
);

CREATE TABLE Updates (
  id INTEGER,
  time TIMESTAMP,
  PRIMARY KEY (id, time),
  FOREIGN KEY (id) REFERENCES Projects(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Employees (
  id     SERIAL,
  name   TEXT NOT NULL,
  salary MONEY NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE Verifies (
  user_id TEXT,
  employee_id INTEGER NOT NULL,
  date DATE NOT NULL,
  PRIMARY KEY (user_id),
  FOREIGN KEY (user_id) REFERENCES Users(email),
  FOREIGN KEY (employee_id) REFERENCES Employees(id)
);

CREATE TYPE refund_request_status AS ENUM('Approved', 'Rejected');

CREATE TABLE RefundRequest (
  project_id INTEGER,
  backer_id TEXT,
  employee_id INTEGER,
  submission_date DATE NOT NULL,
  processed_date  DATE,
  status REFUND_REQUEST_STATUS,
  PRIMARY KEY (project_id, backer_id),
  FOREIGN KEY (project_id) REFERENCES Projects(id),
  FOREIGN KEY (backer_id) REFERENCES Backers(email),
  FOREIGN KEY (employee_id) REFERENCES Employees(id)
);

CREATE TABLE Process (
  
);

CREATE TABLE ProjectRewardLevel (
  project_id INTEGER,
  name       TEXT,
  min_amount MONEY NOT NULL,
  PRIMARY KEY (project_id, name),
  FOREIGN KEY (project_id) REFERENCES Projects(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Funds (
  project_id INTEGER,
  backer_id TEXT,
  level_name TEXT NOT NULL,
  amount MONEY NOT NULL,
  PRIMARY KEY (project_id, backer_id, level_name),
  UNIQUE (project_id, backer_id),
  FOREIGN KEY (project_id) REFERENCES Projects(id),
  FOREIGN KEY (backer_id) REFERENCES Backers(email),
  FOREIGN KEY (project_id, level_name) REFERENCES ProjectRewardLevel(project_id, name)
);
