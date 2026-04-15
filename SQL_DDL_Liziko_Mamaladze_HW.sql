------------------------------------------------------------------------------
-- Creating new database and schema based on Social Media relational model. 
-- COMMIT is set on automatic for this step.
------------------------------------------------------------------------------

CREATE DATABASE social_media_db;

-- Created the database and connected to it,
-- so next operations are applied to the correct database.

CREATE SCHEMA core;

-- Created the 'core' schema that represents the main domain of the application,
-- containing all essential entities of the social media platform.
-- Set it as default.

--------------------------------------------------------------------------------
-- Creating Tables 
-- Unlike ERD, here I created table names and column names in lower case, 
-- to align with coding standarts and primary keys are written like <table>_id instead. 

-- Common constraint explanations are bellow (after the table creation queries). 
--------------------------------------------------------------------------------
-- Table: user (parent table)

CREATE TABLE core.user (
    user_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_name VARCHAR(50) NOT NULL UNIQUE,
    email_info VARCHAR(100) NOT NULL UNIQUE,
    phone_number VARCHAR(20) UNIQUE,
    password VARCHAR(255) NOT NULL,
    creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_creation_time
        CHECK (creation_time > '2000-01-01')
);    

------------------------------------------------------------------------------------
-- Table: media_type (parent table)

CREATE TABLE core.media_type (
    media_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    media_type_name VARCHAR(20) NOT NULL UNIQUE,
    CONSTRAINT chk_media_type
        CHECK (media_type_name IN ('image', 'video', 'gif'))
);

-- CHECK (media_type_name IN ('image', 'video', 'gif'))
-- Restricts values to a predefined set, ensuring data consistency,
-- as there can only be these 3 media types.
-- Without it: inconsistent data and system errors.

---------------------------------------------------------------------------
-- Table: visibility_setting (parent table)

CREATE TABLE core.visibility_setting (
    visibility_setting_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    visibility_type VARCHAR(20) NOT NULL UNIQUE,
    CONSTRAINT chk_visibility
        CHECK (visibility_type IN ('public', 'followers', 'private'))
);

-- Same viewpoint here on CHECK constraint as in media_type table,
-- there are only these three settings on a platform.

---------------------------------------------------------------------------
-- Table: hashtag (parent table)

CREATE TABLE core.hashtag (
    hashtag_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hashtag_name VARCHAR(50) NOT NULL UNIQUE
);

---------------------------------------------------------------------------
-- Table: share_platform (parent table)

CREATE TABLE core.share_platform (
    share_platform_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    platform_name VARCHAR(50) NOT NULL UNIQUE
);

-- This is a lookup table were many platforms can be added 
-- so restricting values with CHECK would reduce flexibility, as adding new media types
-- would require altering the table. Lookup tables
-- alone are typically sufficient to control allowed values.

----------------------------------------------------------------------------
-- Table: profile (dependent table)

CREATE TABLE core.profile (
    profile_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    bio TEXT,
    birth_date DATE,
    location VARCHAR(50),
    FOREIGN KEY (user_id) REFERENCES core.user(user_id)
);

-- UNIQUE (user_id) ensures one-to-one relationship (one profile per user)

-- FOREIGN KEY (user_id) REFERENCES user(user_id)
-- Ensures that each profile is linked to an existing user.
-- Prevents insertion of profiles for non-existing users.
-- Without FK:
-- orphan records could exist (profile without user)
-- data integrity would be broken

-- DATE is used for birth_date to store only date (no time needed).
-- TEXT is used for bio because it may contain longer content.
-- These columns do not require any constraints, as they can be left empty 
-- and repeated for deferent users

---------------------------------------------------------------------------
-- Table: post(dependent table)

CREATE TABLE core.post (
    post_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INT NOT NULL,
    visibility_setting_id INT NOT NULL,
    creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    description TEXT,
    FOREIGN KEY (user_id) REFERENCES core.user(user_id),
    FOREIGN KEY (visibility_setting_id) REFERENCES core.visibility_setting(visibility_setting_id),
    CONSTRAINT chk_post_deleted_after_creation
        CHECK (deleted_at IS NULL OR deleted_at > creation_time),
    CONSTRAINT chk_post_creation_time
        CHECK (creation_time > '2000-01-01')
);

-- FOREIGN KEY (user_id)
-- Ensures each post belongs to an existing user.
-- Without it: posts could reference non-existing users.

-- FOREIGN KEY (visibility_setting_id)
-- Ensures post visibility matches predefined settings.
-- Without it: invalid visibility values could be assigned.

-- CHECK (deleted_at IS NULL OR deleted_at > creation_time)
-- Ensures logical time order (cannot delete before creation).
-- Without it: inconsistent timestamps could exist.

---------------------------------------------------------------------------
-- Table: follow (dependent table + self relationship)

CREATE TABLE core.follow (
    follower_user_id INT,
    following_user_id INT,
    follow_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    removal_time TIMESTAMP,
    PRIMARY KEY (follower_user_id, following_user_id),
    FOREIGN KEY (follower_user_id) REFERENCES core.user(user_id),
    FOREIGN KEY (following_user_id) REFERENCES core.user(user_id),
    CONSTRAINT chk_no_self_follow
        CHECK (follower_user_id <> following_user_id),
    CONSTRAINT chk_follow_time
        CHECK (follow_time > '2000-01-01'),
    CONSTRAINT chk_removal_after_follow
        CHECK (removal_time IS NULL OR removal_time > follow_time)
);

-- PRIMARY KEY (follower_user_id, following_user_id)
-- Is a composite key and Ensures each follow relationship is unique 
-- and prevents duplicate follow records.
-- Without it: same user could follow another multiple times.

-- FOREIGN KEY (follower_user_id, following_user_id)
-- Ensures both users exist in the user table and prevents relationships with non-existing users.
-- Without it: invalid or orphan relationships could exist.

-- CHECK (follower_user_id <> following_user_id)
-- Prevents a user from following themselves.
-- Without it: illogical relationships could be stored.

-- CHECK (removal_time IS NULL OR removal_time > follow_time)
-- Ensures correct time sequence.
-- Without it: removal could occur before follow, causing inconsistency.

------------------------------------------------------------------------------
-- TABLE: comment (relationship table)

CREATE TABLE core.comment (
    comment_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    comment_text TEXT NOT NULL,
    creation_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES core.post(post_id),
    FOREIGN KEY (user_id) REFERENCES core.user(user_id),
    CONSTRAINT chk_comment_creation_time
        CHECK (creation_time > '2000-01-01'),
    CONSTRAINT chk_comment_deleted_after_creation
        CHECK (deleted_at IS NULL OR deleted_at > creation_time)
);

-- FOREIGN KEY (post_id)
-- Ensures comment is linked to an existing post.
-- Without it: comments could reference non-existing posts.

-- FOREIGN KEY (user_id)
-- Ensures comment is made by an existing user.
-- Without it: invalid user references could exist.

-- CHECK (deleted_at IS NULL OR deleted_at > creation_time)
-- Ensures correct time order.
-- Without it: deletion could occur before creation.

----------------------------------------------------------------------------
-- TABLE: like (relationship table)

CREATE TABLE core."like" (
    like_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    liked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    unliked_at TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES core.post(post_id),
    FOREIGN KEY (user_id) REFERENCES core.user(user_id),
    CONSTRAINT unq_post_like_user_post
        UNIQUE (post_id, user_id),
    CONSTRAINT chk_like_time
        CHECK (liked_at > '2000-01-01'),
    CONSTRAINT chk_unliked_after_liked
        CHECK (unliked_at IS NULL OR unliked_at > liked_at)
);

-- FOREIGN KEY (post_id)
-- Ensures like is linked to an existing post.
-- Without it: likes could reference non-existing posts.

-- FOREIGN KEY (user_id)
-- Ensures like is made by an existing user.
-- Without it: invalid user references could exist.

-- UNIQUE (post_id, user_id)
-- Ensures a user can like a post only once.
-- Without it: same user could like the same post multiple times.

-- CHECK (unliked_at IS NULL OR unliked_at > liked_at)
-- Ensures correct time order.
-- Without it: unlike could occur before like.

----------------------------------------------------------------------------
-- TABLE: share (relationship table)

CREATE TABLE core.share (
    share_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    share_platform_id INT NOT NULL,
    shared_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES core.post(post_id),
    FOREIGN KEY (user_id) REFERENCES core.user(user_id),
    FOREIGN KEY (share_platform_id) REFERENCES core.share_platform(share_platform_id),
    CONSTRAINT chk_share_time
        CHECK (shared_at > '2000-01-01')
);

-- FOREIGN KEY (post_id)
-- Ensures the shared post exists.
-- Without it: shares could reference non-existing posts.

-- FOREIGN KEY (user_id)
-- Ensures the share is made by an existing user.
-- Without it: invalid user references could exist.

-- FOREIGN KEY (share_platform_id)
-- Ensures share platform is valid and predefined.
-- Without it: invalid platforms could be assigned.

-------------------------------------------------------------------------------
-- TABLE: post_media (relationship table)

CREATE TABLE core.post_media (
    post_media_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    post_id INT NOT NULL,
    media_type_id INT NOT NULL,
    uploaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    removed_at TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES core.post(post_id),
    FOREIGN KEY (media_type_id) REFERENCES core.media_type(media_type_id),
    CONSTRAINT chk_upload_time
        CHECK (uploaded_at > '2000-01-01'),
    CONSTRAINT chk_removed_after_upload
        CHECK (removed_at IS NULL OR removed_at > uploaded_at)
);

-- FOREIGN KEY (post_id)
-- Ensures media is linked to an existing post.
-- Without it: media could reference non-existing posts.

-- FOREIGN KEY (media_type_id)
-- Ensures media type is valid and predefined.
-- Without it: invalid media types could be assigned.

-- CHECK (removed_at IS NULL OR removed_at > uploaded_at)
-- Ensures correct time order.
-- Without it: removal could occur before upload.

------------------------------------------------------------------------------
-- TABLE: post_hashtag (bridge table)

CREATE TABLE core.post_hashtag (
    post_id INT,
    hashtag_id INT,
    PRIMARY KEY (post_id, hashtag_id),
    FOREIGN KEY (post_id) REFERENCES core.post(post_id),
    FOREIGN KEY (hashtag_id) REFERENCES core.hashtag(hashtag_id)
);

-- PRIMARY KEY (post_id, hashtag_id)
-- Is a composite key and Ensures each hashtag is linked to a post only once.
-- Prevents duplicate post-hashtag relationships.

-- FOREIGN KEY (post_id)
-- Ensures the post exists.
-- Without it: invalid post references could exist.

-- FOREIGN KEY (hashtag_id)
-- Ensures the hashtag exists.
-- Without it: invalid hashtag references could exist.

------------------------------------------------------------------------------
-- Common Constraints for all tables:

-- Added NOT NULL on foreign key columns so it ensures that every record
-- must be linked to an existing parent record.
-- Without it relationships could be missing (e.g., post without user),
-- leading to incomplete and inconsistent data.

-- PRIMARY KEY
-- Primary keys are defined for all tables to uniquely identify each record.
-- They ensure entity integrity and allow reliable referencing from other tables.
-- Without PRIMARY KEY:
-- Duplicate or indistinguishable records could exist.
-- Foreign key relationships would become unreliable.

-- FOREIGN KEY
-- Foreign keys are used to enforce relationships between tables.

-- NOT NULL
-- Is applied to required attributes to ensure that essential data is always provided.
-- Without NOT NULL:
-- Incomplete records could be inserted.
-- System functionality (e.g., login, relationships) could fail.

-- UNIQUE
-- Constraints are applied to attributes that must not be duplicated
-- (e.g., usernames, emails, platform names).
-- Without UNIQUE:
-- Duplicate values could exist.
-- Ambiguity in identifying records would occur.
-- Data consistency would be compromised.

-- DEFAULT (especially for timestamps)
-- DEFAULT values (e.g., CURRENT_TIMESTAMP) are used to automatically assign values
-- when none are provided during insertion.
-- This is especially important for date/time attributes such as creation_time,
-- liked_at, follow_time, etc.
-- Without DEFAULT:
-- Timestamps might be missing or inconsistent.
-- Manual input could lead to errors.

-- CHECK on dates (e.g., > '2000-01-01')
-- Ensures that all stored timestamps are realistic and valid.
-- Without this:
-- Incorrect or unrealistic dates could be stored.
-- Time-based operations (sorting, analytics) could be affected.

-- GENERATED ALWAYS AS IDENTITY
-- Used for automatic generation of primary key values.
-- Ensures no manual insertion errors.
-- Without this:
-- IDs would need manual management.
-- High risk of duplicates and conflicts.

----------------------------------------------------------------------------------
-- Explanation of the tables creation part:

-- Choosing incorrect data types can lead to:
-- Data loss (using INT for phone numbers removes leading zeros, '+' character or '()' ),
-- Invalid data storage (storing dates as VARCHAR allows incorrect formats),
-- Performance issues (using TEXT instead of VARCHAR increases storage and slows queries) and 
-- Inaccurate comparisons and calculations. Therefore,
-- proper data types ensure data accuracy, efficient storage, and correct query behavior.

-- Constraints ensure data integrity and consistency, and what could occure without them
-- and why I used the ones I did are already explained above.

-- If foreign keys are not defined:
-- Records could reference non-existing entities and data relationships would not be enforced
-- (explanaion in more details above).

-- Tables must be created in the correct order:
-- parent tables first, then dependent tables.
-- If the order is incorrect: FOREIGN KEY errors will occur.
-- The system will reject table creation because referenced tables do not exist.
-- Example: Creating "post" before "user" will fail because user_id references user(user_id).
-- Correct order ensures smooth creation of relationships and avoids execution errors.

-------------------------------------------------------------------------------------
-- Adding data to tables: chose two rows from word file examples provided in my DB homework.
-- Turned off the auto COMMIT.
-------------------------------------------------------------------------------------
-- INSERT INTO user 

BEGIN ;
INSERT INTO core."user" (user_name, email_info, phone_number, password, creation_time)
SELECT *
FROM (
    VALUES
    ('liziko_m', 'liziko@gmail.com', '+995591330044', 'Fvfvfvfvfv!!!', TIMESTAMP '2026-03-10 14:22:31'),
    ('david_k', 'david@gmail.com', '+995551112233', 'isisisisisis@@@', TIMESTAMP '2026-03-11 09:15:12')
) AS v(user_name, email_info, phone_number, password, creation_time)
WHERE NOT EXISTS (
    SELECT 1
    FROM core."user" u
    WHERE LOWER(u.user_name) = LOWER(v.user_name)
       OR LOWER(u.email_info) = LOWER(v.email_info)
)
RETURNING *;
COMMIT ;

SELECT *
FROM core."user" u ;

------------------------------------------------------------------------------
-- INSERT INTO media_type

BEGIN ;
INSERT INTO core.media_type (media_type_name)
SELECT *
FROM (
    VALUES
    ('image'),
    ('video')
) AS v(media_type_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM core.media_type m
    WHERE LOWER(m.media_type_name) = LOWER(v.media_type_name)
)
RETURNING *;
COMMIT ;

SELECT *
FROM core.media_type mt ;

-------------------------------------------------------------------------------
-- INSERT INTO visibility_setting

BEGIN ;
INSERT INTO core.visibility_setting (visibility_type)
SELECT *
FROM (
    VALUES
    ('public'),
    ('followers')
) AS v(visibility_type)
WHERE NOT EXISTS (
    SELECT 1
    FROM core.visibility_setting vs
    WHERE LOWER(vs.visibility_type) = LOWER(v.visibility_type)
)
RETURNING * ;
COMMIT ;

SELECT *
FROM core.visibility_setting vs ;

-------------------------------------------------------------------------------
-- INSERT INTO hashtag

BEGIN ;
INSERT INTO core.hashtag (hashtag_name)
SELECT *
FROM (
    VALUES
    ('travel'),
    ('sunset')
) AS v(hashtag_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM core.hashtag h
    WHERE LOWER(h.hashtag_name) = LOWER(v.hashtag_name)
)
RETURNING * ;
COMMIT ;

SELECT *
FROM core.hashtag h ;

-------------------------------------------------------------------------------
-- INSERT INTO share_platform

BEGIN ;
INSERT INTO core.share_platform (platform_name)
SELECT *
FROM (
    VALUES
    ('facebook'),
    ('instagram')
) AS v(platform_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM core.share_platform sp
    WHERE LOWER(sp.platform_name) = LOWER(v.platform_name)
)
RETURNING * ;
COMMIT ;

SELECT *
FROM core.share_platform sp ;

-------------------------------------------------------------------------------
-- INSERT INTO profile

BEGIN ;
INSERT INTO core.profile (user_id, first_name, last_name, bio, birth_date, location)
SELECT *
FROM ( 
	VALUES
    (
        (SELECT user_id FROM core."user" WHERE LOWER(user_name) = 'liziko_m'),
        'Liziko', 'Mamaladze', 'Data Analyst', DATE '2005-10-04', 'Guramishvili Avenue 12'
    ),
    (
        (SELECT user_id FROM core."user" WHERE LOWER(user_name) = 'david_k'),
        'David', 'Kapanadze', 'Photographer', DATE '2002-05-19', 'Chavchavadze Avenue 12'
    )
) AS v(user_id, first_name, last_name, bio, birth_date, location)
WHERE NOT EXISTS (
    SELECT 1
    FROM core.profile p
    WHERE p.user_id = v.user_id
)
RETURNING * ;
COMMIT ;

SELECT *
FROM core.profile p ;

--------------------------------------------------------------------------------
-- INSERT INTO post

BEGIN ;
INSERT INTO core.post (user_id, visibility_setting_id, creation_time, deleted_at, description)
SELECT *
FROM (
	VALUES
    (
        (SELECT user_id FROM core."user" WHERE LOWER(user_name) = 'liziko_m'),
        (SELECT visibility_setting_id FROM core.visibility_setting WHERE LOWER(visibility_type) = 'public'),
        TIMESTAMP '2026-03-10 14:22:05', NULL::TIMESTAMP, 'Sunset in Tbilisi'
    ),
    (
        (SELECT user_id FROM core."user" WHERE LOWER(user_name) = 'david_k'),
        (SELECT visibility_setting_id FROM core.visibility_setting WHERE LOWER(visibility_type) = 'public'),
        TIMESTAMP '2026-03-10 14:25:35', NULL::TIMESTAMP, 'Weekend trip'
    )
) AS v(user_id, visibility_setting_id, creation_time, deleted_at, description)
WHERE NOT EXISTS (
    SELECT 1
    FROM core.post p
    WHERE p.user_id = v.user_id
      AND LOWER(p.description) = LOWER(v.description)
)
RETURNING *;
COMMIT ;

SELECT *
FROM core.post p ;
--------------------------------------------------------------------------------------
-- INSERT INTO follow
-- Liziko follows David
-- David follows Liziko

BEGIN;
INSERT INTO core.follow (follower_user_id, following_user_id, follow_time, removal_time)
SELECT *
FROM (
    VALUES
    (
        (SELECT user_id FROM core."user" WHERE LOWER(user_name) = 'liziko_m'),
        (SELECT user_id FROM core."user" WHERE LOWER(user_name) = 'david_k'),
        TIMESTAMP '2026-03-10 00:00:00', NULL::TIMESTAMP
    ),
    (
        (SELECT user_id FROM core."user" WHERE LOWER(user_name) = 'david_k'),
        (SELECT user_id FROM core."user" WHERE LOWER(user_name) = 'liziko_m'),
        TIMESTAMP '2026-03-11 00:00:00', NULL::TIMESTAMP
    )
) AS v(follower_user_id, following_user_id, follow_time, removal_time)
WHERE NOT EXISTS (
    SELECT 1
    FROM core.follow f
    WHERE f.follower_user_id = v.follower_user_id
      AND f.following_user_id = v.following_user_id
)
RETURNING * ;
COMMIT;

SELECT *
FROM core.follow f ;

--------------------------------------------------------------------------------------
-- INSERT INTO comment
-- David commented on Liziko's post
-- Liziko commented on David's post
BEGIN;
INSERT INTO core.comment (post_id, user_id, comment_text, creation_time, deleted_at)
SELECT *
FROM (
    VALUES
    (
        (
            SELECT p.post_id
            FROM core.post p
            JOIN core."user" u ON p.user_id = u.user_id
            WHERE LOWER(u.user_name) = 'liziko_m'
              AND p.creation_time = TIMESTAMP '2026-03-10 14:22:05'
        ),
        (SELECT user_id FROM core."user" WHERE LOWER(user_name) = 'david_k'),
        'Amazing photo!', TIMESTAMP '2026-03-10 14:35:20', NULL::TIMESTAMP
    ),
    (
        (
            SELECT p.post_id
            FROM core.post p
            JOIN core."user" u ON p.user_id = u.user_id
            WHERE LOWER(u.user_name) = 'david_k'
              AND p.creation_time = TIMESTAMP '2026-03-10 14:25:35'
        ),
        (SELECT user_id FROM core."user" WHERE LOWER(user_name) = 'liziko_m'),
        'Great post!', TIMESTAMP '2026-03-11 09:25:10', TIMESTAMP '2026-03-11 10:05:00'
    )
) AS v(post_id, user_id, comment_text, creation_time, deleted_at)
WHERE NOT EXISTS (
    SELECT 1
    FROM core.comment c
    WHERE c.post_id = v.post_id
      AND c.user_id = v.user_id
      AND LOWER(c.comment_text) = LOWER(v.comment_text)
)
RETURNING * ;
COMMIT;

SELECT *
FROM core."comment" c ;

-- As one user can create many post and we have to identify only one to add the data,
-- post_id is identified using user_name and creation_time to ensure accuracy.
-- Description is not used because it may not be unique.
-- This approach avoids ambiguity and ensures correct relationships.

-------------------------------------------------------------------------------------------
-- INSERT INTO like
-- David likes Liziko's post
-- Liziko likes then unlikes David's post 

BEGIN;
INSERT INTO core."like" (post_id, user_id, liked_at, unliked_at)
SELECT *
FROM (
    VALUES
    (
        (
            SELECT p.post_id
            FROM core.post p
            JOIN core."user" u ON p.user_id = u.user_id
            WHERE LOWER(u.user_name) = 'liziko_m'
              AND p.creation_time = TIMESTAMP '2026-03-10 14:22:05'
        ),
        (SELECT user_id FROM core."user" WHERE LOWER(user_name) = 'david_k'),
        TIMESTAMP '2026-03-10 14:30:12', NULL::TIMESTAMP
    ),
    (
        (
            SELECT p.post_id
            FROM core.post p
            JOIN core."user" u ON p.user_id = u.user_id
            WHERE LOWER(u.user_name) = 'david_k'
              AND p.creation_time = TIMESTAMP '2026-03-10 14:25:35'
        ),
        (SELECT user_id FROM core."user" WHERE LOWER(user_name) = 'liziko_m'),
        TIMESTAMP '2026-03-10 14:31:45', TIMESTAMP '2026-03-12 08:15:00'
    )
) AS v(post_id, user_id, liked_at, unliked_at)
WHERE NOT EXISTS (
    SELECT 1
    FROM core."like" l
    WHERE l.post_id = v.post_id
      AND l.user_id = v.user_id
)
RETURNING * ;
COMMIT ;

SELECT *
FROM core."like" l ;

-- Post Id here is also identified by user name and creation time, to specify correct post.

-------------------------------------------------------------------------------------
-- INSERT INTO shere
-- Liziko shares David's post on Instagram
-- David shares Liziko's post on Facebook

BEGIN;
INSERT INTO core.share (post_id, user_id, share_platform_id, shared_at)
SELECT *
FROM (
    VALUES
    (
        (
            SELECT p.post_id
            FROM core.post p
            JOIN core."user" u ON p.user_id = u.user_id
            WHERE LOWER(u.user_name) = 'liziko_m'
              AND p.creation_time = TIMESTAMP '2026-03-10 14:22:05'
        ),
        (SELECT user_id FROM core."user" WHERE LOWER(user_name) = 'david_k'),
        (SELECT share_platform_id FROM core.share_platform WHERE LOWER(platform_name) = 'facebook'),
        TIMESTAMP '2026-03-10 14:40:15'
    ),
    (
        (
            SELECT p.post_id
            FROM core.post p
            JOIN core."user" u ON p.user_id = u.user_id
            WHERE LOWER(u.user_name) = 'david_k'
              AND p.creation_time = TIMESTAMP '2026-03-10 14:25:35'
        ),
        (SELECT user_id FROM core."user" WHERE LOWER(user_name) = 'liziko_m'),
        (SELECT share_platform_id FROM core.share_platform WHERE LOWER(platform_name) = 'instagram'),
        TIMESTAMP '2026-03-11 09:35:22'
    )
) AS v(post_id, user_id, share_platform_id, shared_at)
WHERE NOT EXISTS (
    SELECT 1
    FROM core.share s
    WHERE s.post_id = v.post_id
      AND s.user_id = v.user_id
      AND s.share_platform_id = v.share_platform_id
)
RETURNING * ;
COMMIT ;

SELECT * 
FROM core."share" s ;

----------------------------------------------------------------------------------------------
-- INSERT INTO post_media
-- Post 1 (Liziko) - Image
-- Post 1 (Liziko) - Video
-- Post 2 (David) - Image (later removed)

BEGIN;
INSERT INTO core.post_media (post_id, media_type_id, uploaded_at, removed_at)
SELECT *
FROM (
    VALUES
    (
        (
            SELECT p.post_id
            FROM core.post p
            JOIN core."user" u ON p.user_id = u.user_id
            WHERE LOWER(u.user_name) = 'liziko_m'
              AND p.creation_time = TIMESTAMP '2026-03-10 14:22:05'
        ),
        (SELECT media_type_id FROM core.media_type WHERE LOWER(media_type_name) = 'image'),
        TIMESTAMP '2026-03-10 14:25:10', NULL::TIMESTAMP
    ),
    (
        (
            SELECT p.post_id
            FROM core.post p
            JOIN core."user" u ON p.user_id = u.user_id
            WHERE LOWER(u.user_name) = 'liziko_m'
              AND p.creation_time = TIMESTAMP '2026-03-10 14:22:05'
        ),
        (SELECT media_type_id FROM core.media_type WHERE LOWER(media_type_name) = 'video'),
        TIMESTAMP '2026-03-10 14:26:35', NULL::TIMESTAMP
    ),
    (
        (
            SELECT p.post_id
            FROM core.post p
            JOIN core."user" u ON p.user_id = u.user_id
            WHERE LOWER(u.user_name) = 'david_k'
              AND p.creation_time = TIMESTAMP '2026-03-10 14:25:35'
        ),
        (SELECT media_type_id FROM core.media_type WHERE LOWER(media_type_name) = 'image'),
        TIMESTAMP '2026-03-11 09:18:42', TIMESTAMP '2026-03-12 10:05:12'
    )
) AS v(post_id, media_type_id, uploaded_at, removed_at)
WHERE NOT EXISTS (
    SELECT 1
    FROM core.post_media pm
    WHERE pm.post_id = v.post_id
      AND pm.media_type_id = v.media_type_id
      AND pm.uploaded_at = v.uploaded_at
)
RETURNING * ;
COMMIT ;

SELECT *
FROM core.post_media pm ;

---------------------------------------------------------------------------------------
-- INSERT INTO post_hashtag
-- Post 1 (Liziko) - travel
-- Post 1 (Liziko) - sunset
-- Post 2 (David) - travel

BEGIN;
INSERT INTO core.post_hashtag (post_id, hashtag_id)
SELECT *
FROM (
    VALUES
    (
        (
            SELECT p.post_id
            FROM core.post p
            JOIN core."user" u ON p.user_id = u.user_id
            WHERE LOWER(u.user_name) = 'liziko_m'
              AND p.creation_time = TIMESTAMP '2026-03-10 14:22:05'
        ),
        (SELECT hashtag_id FROM core.hashtag WHERE LOWER(hashtag_name) = 'travel')
    ),
    (
        (
            SELECT p.post_id
            FROM core.post p
            JOIN core."user" u ON p.user_id = u.user_id
            WHERE LOWER(u.user_name) = 'liziko_m'
              AND p.creation_time = TIMESTAMP '2026-03-10 14:22:05'
        ),
        (SELECT hashtag_id FROM core.hashtag WHERE LOWER(hashtag_name) = 'sunset')
    ),
    (
        (
            SELECT p.post_id
            FROM core.post p
            JOIN core."user" u ON p.user_id = u.user_id
            WHERE LOWER(u.user_name) = 'david_k'
              AND p.creation_time = TIMESTAMP '2026-03-10 14:25:35'
        ),
        (SELECT hashtag_id FROM core.hashtag WHERE LOWER(hashtag_name) = 'travel')
    )
) AS v(post_id, hashtag_id)
WHERE NOT EXISTS (
    SELECT 1
    FROM core.post_hashtag ph
    WHERE ph.post_id = v.post_id
      AND ph.hashtag_id = v.hashtag_id
)
RETURNING post_id, hashtag_id;
COMMIT ;

SELECT *
FROM core.post_hashtag ph ;

--------------------------------------------------------------------------------------------
-- Data Insertation: Consistency and Relationships

-- Data consistency is ensured by avoiding hardcoded primary key values.
-- Instead, foreign key values are dynamically retrieved using SELECT queries
-- based on unique attributes (user_name, visibility_type, platform_name).
-- This approach guarantees that inserted records always reference the correct rows.
-- WHERE NOT EXISTS is used in all INSERT statements to prevent duplicate data and
-- this ensures that the script can be safely executed multiple times
-- without inserting the same records again.
-- Case-insensitive comparisons (LOWER function) are used when matching text values,
-- ensuring consistency even if data differs in letter case.
-- Explicit type casting (NULL::TIMESTAMP) is applied where needed
-- to ensure correct data types and prevent insertion errors that occured without casting.

-- Relationships between tables are preserved by using foreign keys
-- and ensuring that referenced data exists before inserting dependent records.
-- Parent tables are populated first, followed by dependent and relationship tables,
-- which guarantees that all foreign key references are valid, 
-- it was also crutial for table creation part.
-- For identifying posts, a combination of user_name and creation_time is used.
-- This avoids ambiguity.
------------------------------------------------------------------------------------------------
-- Adding a not null 'record_ts' field to each table using ALTER TABLE statements, 
-- setting the default value to current_date, 
-- and checking to make sure the value has been set for the existing rows.

BEGIN;

ALTER TABLE core."user"
ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE core.media_type
ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE core.visibility_setting
ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE core.hashtag
ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE core.share_platform
ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE core.profile
ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE core.post
ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE core.follow
ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE core.comment
ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE core."like"
ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE core.share
ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE core.post_media
ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE core.post_hashtag
ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

COMMIT ;

-- Turned auto COMMIT on for this next checking.

SELECT user_id, record_ts FROM core."user" ;

SELECT post_id, record_ts FROM core.post p ;

SELECT comment_id, record_ts FROM core."comment" c ;

-- ... and we can check like this for other tables. 

-- In this case we have few rows, for big data we can use this (seperatly for all tables):
SELECT COUNT(*) AS total_rows,
       COUNT(record_ts) AS non_null_record_ts
FROM core.post;
-- if total_rows = non_null_record_ts then everything is correct.

