/* Triggers are a good thing, didnt know.... */
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS news_article_media;
DROP TABLE IF EXISTS news_breaking;
DROP TABLE IF EXISTS news_media;
DROP TABLE IF EXISTS news_articles;

DROP TABLE IF EXISTS ems_pharmacy_moves;
DROP TABLE IF EXISTS ems_pharmacy_stock;
DROP TABLE IF EXISTS ems_lab_results;
DROP TABLE IF EXISTS ems_triage;
DROP TABLE IF EXISTS ems_incidents;

DROP TABLE IF EXISTS mdt_evidences;
DROP TABLE IF EXISTS mdt_warrants;
DROP TABLE IF EXISTS mdt_case_people;
DROP TABLE IF EXISTS mdt_reports;
DROP TABLE IF EXISTS mdt_cases;

/* ==========================================================
   POLICE / MDT
   ========================================================== */

CREATE TABLE IF NOT EXISTS mdt_cases (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  type            VARCHAR(50) NOT NULL, -- e.g. 'robbery','assault','homicide'
  title           VARCHAR(150) NOT NULL,
  description     TEXT NULL,
  status          ENUM('open','investigating','closed','archived') NOT NULL DEFAULT 'open',
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NULL,
  created_by_cid  VARCHAR(50) NOT NULL,
  last_editor_cid VARCHAR(50) NULL,

  INDEX idx_mdt_cases_status (status),
  INDEX idx_mdt_cases_type (type),
  INDEX idx_mdt_cases_created_by (created_by_cid),
  INDEX idx_mdt_cases_last_editor (last_editor_cid),

  CONSTRAINT fk_mdt_cases_created_by
    FOREIGN KEY (created_by_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE RESTRICT,

  CONSTRAINT fk_mdt_cases_last_editor
    FOREIGN KEY (last_editor_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS mdt_reports (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  reporter_cid  VARCHAR(50) NULL,
  accused_cid   VARCHAR(50) NULL,
  type          VARCHAR(50) NOT NULL,  -- report type (not necessarily same as case type)
  description   TEXT NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status        ENUM('new','reviewing','converted','dismissed') NOT NULL DEFAULT 'new',
  case_id       INT NULL,

  INDEX idx_mdt_reports_status (status),
  INDEX idx_mdt_reports_case (case_id),
  INDEX idx_mdt_reports_reporter (reporter_cid),
  INDEX idx_mdt_reports_accused (accused_cid),

  CONSTRAINT fk_mdt_reports_reporter
    FOREIGN KEY (reporter_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE SET NULL,

  CONSTRAINT fk_mdt_reports_accused
    FOREIGN KEY (accused_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE SET NULL,

  CONSTRAINT fk_mdt_reports_case
    FOREIGN KEY (case_id) REFERENCES mdt_cases(id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS mdt_case_people (
  id        INT AUTO_INCREMENT PRIMARY KEY,
  case_id   INT NOT NULL,
  citizenid VARCHAR(50) NOT NULL,
  role      ENUM('suspect','victim','witness','officer') NOT NULL,
  note      VARCHAR(255) NULL,

  UNIQUE KEY uq_mdt_case_people (case_id, citizenid, role),
  INDEX idx_mdt_case_people_case (case_id),
  INDEX idx_mdt_case_people_citizen (citizenid),

  CONSTRAINT fk_mdt_case_people_case
    FOREIGN KEY (case_id) REFERENCES mdt_cases(id)
    ON UPDATE CASCADE ON DELETE CASCADE,

  CONSTRAINT fk_mdt_case_people_citizen
    FOREIGN KEY (citizenid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS mdt_evidences (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  case_id      INT NOT NULL,
  type         VARCHAR(50) NOT NULL,   -- 'photo','video','note','file'
  description  TEXT NULL,
  file_path    VARCHAR(255) NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  added_by_cid VARCHAR(50) NOT NULL,

  INDEX idx_mdt_evidences_case (case_id),
  INDEX idx_mdt_evidences_added_by (added_by_cid),

  CONSTRAINT fk_mdt_evidences_case
    FOREIGN KEY (case_id) REFERENCES mdt_cases(id)
    ON UPDATE CASCADE ON DELETE CASCADE,

  CONSTRAINT fk_mdt_evidences_added_by
    FOREIGN KEY (added_by_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS mdt_warrants (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  case_id          INT NOT NULL,
  target_citizenid VARCHAR(50) NULL,
  target_address   VARCHAR(255) NULL,
  target_plate     VARCHAR(20) NULL,
  type             ENUM('arrest','search') NOT NULL,
  reason           TEXT NULL,
  issued_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at       DATETIME NULL,
  status           ENUM('active','executed','expired') NOT NULL DEFAULT 'active',
  issued_by_cid    VARCHAR(50) NOT NULL,

  INDEX idx_mdt_warrants_case (case_id),
  INDEX idx_mdt_warrants_target (target_citizenid),
  INDEX idx_mdt_warrants_status (status),

  CONSTRAINT fk_mdt_warrants_case
    FOREIGN KEY (case_id) REFERENCES mdt_cases(id)
    ON UPDATE CASCADE ON DELETE CASCADE,

  CONSTRAINT fk_mdt_warrants_target
    FOREIGN KEY (target_citizenid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE SET NULL,

  CONSTRAINT fk_mdt_warrants_issuer
    FOREIGN KEY (issued_by_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


/* ==========================================================
   EMS / MEDICAL
   ========================================================== */

CREATE TABLE IF NOT EXISTS ems_incidents (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  patient_cid VARCHAR(50) NOT NULL,
  doctor_cid  VARCHAR(50) NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NULL,
  diagnosis   TEXT NULL,
  treatment   TEXT NULL,
  status      ENUM('open','treated','transferred','closed') NOT NULL DEFAULT 'open',

  INDEX idx_ems_incidents_patient (patient_cid),
  INDEX idx_ems_incidents_doctor (doctor_cid),
  INDEX idx_ems_incidents_status (status),

  CONSTRAINT fk_ems_incidents_patient
    FOREIGN KEY (patient_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE RESTRICT,

  CONSTRAINT fk_ems_incidents_doctor
    FOREIGN KEY (doctor_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS ems_triage (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  patient_cid  VARCHAR(50) NULL,
  severity     ENUM('red','yellow','green') NOT NULL,
  reason       TEXT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  assigned_cid VARCHAR(50) NULL,
  incident_id  INT NULL,
  status       ENUM('waiting','in_treatment','finished') NOT NULL DEFAULT 'waiting',

  INDEX idx_ems_triage_patient (patient_cid),
  INDEX idx_ems_triage_assigned (assigned_cid),
  INDEX idx_ems_triage_incident (incident_id),
  INDEX idx_ems_triage_status (status),

  CONSTRAINT fk_ems_triage_patient
    FOREIGN KEY (patient_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE SET NULL,

  CONSTRAINT fk_ems_triage_assigned
    FOREIGN KEY (assigned_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE SET NULL,

  CONSTRAINT fk_ems_triage_incident
    FOREIGN KEY (incident_id) REFERENCES ems_incidents(id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS ems_lab_results (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  incident_id    INT NOT NULL,
  test_type      VARCHAR(50) NOT NULL,   -- 'alcoholemia','toxico','blood', etc.
  result_value   VARCHAR(100) NULL,
  notes          TEXT NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by_cid VARCHAR(50) NOT NULL,

  INDEX idx_ems_lab_incident (incident_id),

  CONSTRAINT fk_ems_lab_incident
    FOREIGN KEY (incident_id) REFERENCES ems_incidents(id)
    ON UPDATE CASCADE ON DELETE CASCADE,

  CONSTRAINT fk_ems_lab_creator
    FOREIGN KEY (created_by_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS ems_pharmacy_stock (
  id       INT AUTO_INCREMENT PRIMARY KEY,
  name     VARCHAR(100) NOT NULL,
  quantity INT NOT NULL DEFAULT 0,

  UNIQUE KEY uq_ems_pharmacy_stock_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS ems_pharmacy_moves (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  drug_id      INT NOT NULL,
  incident_id  INT NULL,
  employee_cid VARCHAR(50) NOT NULL,
  quantity     INT NOT NULL,
  direction    ENUM('in','out') NOT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_ems_pharm_moves_drug (drug_id),
  INDEX idx_ems_pharm_moves_incident (incident_id),
  INDEX idx_ems_pharm_moves_employee (employee_cid),

  CONSTRAINT fk_ems_pharm_moves_drug
    FOREIGN KEY (drug_id) REFERENCES ems_pharmacy_stock(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,

  CONSTRAINT fk_ems_pharm_moves_incident
    FOREIGN KEY (incident_id) REFERENCES ems_incidents(id)
    ON UPDATE CASCADE ON DELETE SET NULL,

  CONSTRAINT fk_ems_pharm_moves_employee
    FOREIGN KEY (employee_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


/* ==========================================================
   NEWS / PRESS
   ========================================================== */

CREATE TABLE IF NOT EXISTS news_articles (
  id                  INT AUTO_INCREMENT PRIMARY KEY,
  slug                VARCHAR(150) NULL UNIQUE,
  title               VARCHAR(150) NOT NULL,
  subtitle            VARCHAR(255) NULL,
  category            VARCHAR(50) NULL,
  status              ENUM('draft','scheduled','published','archived') NOT NULL DEFAULT 'draft',
  cover_image_url     VARCHAR(255) NULL,
  cover_video_url     VARCHAR(255) NULL,
  content_html        MEDIUMTEXT NULL,
  content_json        MEDIUMTEXT NULL,
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME NULL,
  published_at        DATETIME NULL,
  author_cid          VARCHAR(50) NOT NULL,
  related_case_id     INT NULL,
  related_incident_id INT NULL,

  INDEX idx_news_articles_author (author_cid),
  INDEX idx_news_articles_status (status),
  INDEX idx_news_articles_category (category),
  INDEX idx_news_articles_case (related_case_id),
  INDEX idx_news_articles_incident (related_incident_id),

  CONSTRAINT fk_news_articles_author
    FOREIGN KEY (author_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE RESTRICT,

  CONSTRAINT fk_news_articles_case
    FOREIGN KEY (related_case_id) REFERENCES mdt_cases(id)
    ON UPDATE CASCADE ON DELETE SET NULL,

  CONSTRAINT fk_news_articles_incident
    FOREIGN KEY (related_incident_id) REFERENCES ems_incidents(id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS news_media (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  file_path       VARCHAR(255) NOT NULL,
  type            VARCHAR(50) NOT NULL, -- 'image'|'video'
  uploaded_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  uploaded_by_cid VARCHAR(50) NOT NULL,

  INDEX idx_news_media_uploader (uploaded_by_cid),

  CONSTRAINT fk_news_media_uploader
    FOREIGN KEY (uploaded_by_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS news_article_media (
  article_id INT NOT NULL,
  media_id   INT NOT NULL,
  is_main    TINYINT(1) NOT NULL DEFAULT 0,

  PRIMARY KEY (article_id, media_id),

  CONSTRAINT fk_news_article_media_article
    FOREIGN KEY (article_id) REFERENCES news_articles(id)
    ON UPDATE CASCADE ON DELETE CASCADE,

  CONSTRAINT fk_news_article_media_media
    FOREIGN KEY (media_id) REFERENCES news_media(id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS news_breaking (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  title          VARCHAR(150) NOT NULL,
  message        VARCHAR(255) NOT NULL,
  category       VARCHAR(50) NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at     DATETIME NULL,
  article_id     INT NULL,
  created_by_cid VARCHAR(50) NOT NULL,

  INDEX idx_news_breaking_expires (expires_at),
  INDEX idx_news_breaking_article (article_id),

  CONSTRAINT fk_news_breaking_article
    FOREIGN KEY (article_id) REFERENCES news_articles(id)
    ON UPDATE CASCADE ON DELETE SET NULL,

  CONSTRAINT fk_news_breaking_creator
    FOREIGN KEY (created_by_cid) REFERENCES players(citizenid)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


SET FOREIGN_KEY_CHECKS = 1;

DELIMITER $$

/* ---- MDT: keep updated_at current ---- */
DROP TRIGGER IF EXISTS trg_mdt_cases_bu_updated_at $$
CREATE TRIGGER trg_mdt_cases_bu_updated_at
BEFORE UPDATE ON mdt_cases
FOR EACH ROW
BEGIN
  SET NEW.updated_at = NOW();
END $$

/* ---- EMS: keep updated_at current ---- */
DROP TRIGGER IF EXISTS trg_ems_incidents_bu_updated_at $$
CREATE TRIGGER trg_ems_incidents_bu_updated_at
BEFORE UPDATE ON ems_incidents
FOR EACH ROW
BEGIN
  SET NEW.updated_at = NOW();
END $$

/* ---- NEWS: keep updated_at current ---- */
DROP TRIGGER IF EXISTS trg_news_articles_bu_updated_at $$
CREATE TRIGGER trg_news_articles_bu_updated_at
BEFORE UPDATE ON news_articles
FOR EACH ROW
BEGIN
  SET NEW.updated_at = NOW();
END $$

DROP TRIGGER IF EXISTS trg_news_articles_bu_published_at $$
CREATE TRIGGER trg_news_articles_bu_published_at
BEFORE UPDATE ON news_articles
FOR EACH ROW
BEGIN
  IF NEW.status = 'published' AND OLD.status <> 'published' AND NEW.published_at IS NULL THEN
    SET NEW.published_at = NOW();
  END IF;

  IF NEW.status <> 'published' AND OLD.status = 'published' THEN
    SET NEW.published_at = NULL;
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_news_articles_bi_slug $$
CREATE TRIGGER trg_news_articles_bi_slug
BEFORE INSERT ON news_articles
FOR EACH ROW
BEGIN
  IF NEW.slug IS NULL OR NEW.slug = '' THEN
    SET NEW.slug = LOWER(REPLACE(TRIM(NEW.title), ' ', '-'));
    SET NEW.slug = CONCAT(LEFT(NEW.slug, 120), '-', DATE_FORMAT(NOW(), '%Y%m%d%H%i%S'));
  END IF;
  IF NEW.status = 'published' AND NEW.published_at IS NULL THEN
    SET NEW.published_at = NOW();
  END IF;
END $$

DELIMITER ;

