-- =============================================
-- 냉집사 (NaengJibsa) Database Schema
-- DBMS: MySQL 8.0+
-- =============================================

CREATE DATABASE IF NOT EXISTS naengjibsa
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE naengjibsa;

-- =============================================
-- 1. users: 사용자 정보 + 식단 유형 + FCM
-- =============================================
CREATE TABLE users (
    user_id      INT           AUTO_INCREMENT PRIMARY KEY,
    username     VARCHAR(50)   NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    nickname     VARCHAR(50)   NOT NULL,
    diet_type    ENUM('normal', 'vegetarian', 'vegan', 'halal') NOT NULL DEFAULT 'normal',
    fcm_token    VARCHAR(512)  NULL,
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =============================================
-- 2. allergies: 알레르기 코드 테이블
-- =============================================
CREATE TABLE allergies (
    allergy_id   INT           AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(100)  NOT NULL UNIQUE
) ENGINE=InnoDB;

-- 기본 데이터 삽입 (6개)
INSERT INTO allergies (name) VALUES
    ('견과류'), ('유제품'), ('해산물'),
    ('밀'), ('계란'), ('대두');

-- =============================================
-- 3. user_allergies: 사용자-알레르기 매핑 (N:M)
-- =============================================
CREATE TABLE user_allergies (
    user_allergy_id INT       AUTO_INCREMENT PRIMARY KEY,
    user_id         INT       NOT NULL,
    allergy_id      INT       NOT NULL,
    FOREIGN KEY (user_id)    REFERENCES users(user_id)     ON DELETE CASCADE,
    FOREIGN KEY (allergy_id) REFERENCES allergies(allergy_id) ON DELETE CASCADE,
    UNIQUE KEY uq_user_allergy (user_id, allergy_id)
) ENGINE=InnoDB;

-- =============================================
-- 4. cuisines: 요리 장르 코드 테이블
-- =============================================
CREATE TABLE cuisines (
    cuisine_id   INT           AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(100)  NOT NULL UNIQUE
) ENGINE=InnoDB;

-- 기본 데이터 삽입 (4개)
INSERT INTO cuisines (name) VALUES
    ('한식'), ('중식'), ('양식'), ('일식');

-- =============================================
-- 5. user_preferred_cuisines: 사용자-선호장르 매핑 (N:M)
-- =============================================
CREATE TABLE user_preferred_cuisines (
    user_cuisine_id INT       AUTO_INCREMENT PRIMARY KEY,
    user_id         INT       NOT NULL,
    cuisine_id      INT       NOT NULL,
    FOREIGN KEY (user_id)    REFERENCES users(user_id)     ON DELETE CASCADE,
    FOREIGN KEY (cuisine_id) REFERENCES cuisines(cuisine_id) ON DELETE CASCADE,
    UNIQUE KEY uq_user_cuisine (user_id, cuisine_id)
) ENGINE=InnoDB;

-- =============================================
-- 6. ingredients: 냉장고 속 식재료 (단순화)
--    행이 있으면 보유, DELETE하면 없음
-- =============================================
CREATE TABLE ingredients (
    ingredient_id INT          AUTO_INCREMENT PRIMARY KEY,
    user_id       INT          NOT NULL,
    name          VARCHAR(100) NOT NULL,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;
