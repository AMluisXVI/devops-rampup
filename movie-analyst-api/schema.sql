-- Schema from schema.png. Column is release_year (not "release") because seeds.js and /movies use it.
-- Idempotent: safe to run on every Ansible run.
CREATE TABLE IF NOT EXISTS publications (
  name   VARCHAR(250) NOT NULL PRIMARY KEY,
  avatar VARCHAR(250)
);

CREATE TABLE IF NOT EXISTS reviewers (
  name        VARCHAR(255) NOT NULL PRIMARY KEY,
  publication VARCHAR(250),
  avatar      VARCHAR(250),
  FOREIGN KEY (publication) REFERENCES publications (name)
);

CREATE TABLE IF NOT EXISTS movies (
  title        VARCHAR(250) NOT NULL PRIMARY KEY,
  release_year VARCHAR(250),
  score        INT,
  reviewer     VARCHAR(255),
  publication  VARCHAR(250),
  FOREIGN KEY (reviewer) REFERENCES reviewers (name)
);
