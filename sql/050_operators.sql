SET timezone TO 'Zulu';
\x

-- simple data tests
CREATE TABLE uuid_v1_operators (id uuid_v1 PRIMARY KEY);

INSERT INTO uuid_v1_operators (id) VALUES
('1004cd50-4241-11e9-b3ab-db6f0f573554'), -- 2019-03-09 07:58:02.056840
('05602550-8a8c-11e9-b3ab-db6f0f573554'), -- 2019-06-09 07:56:00.175240
('8385ded2-8dbb-11e9-ae2b-db6f0f573554'), -- 2019-06-13 09:13:31.650017
('ffc449f0-8c2f-11e9-aba7-e03f497ffcbf'), -- 2019-06-11 10:02:19.391640
('ffc449f0-8c2f-11e9-96b4-e03f49d7f7bb'), -- 2019-06-11 10:02:19.391640
('ffc449f0-8c2f-11e9-9bb8-e03f4977f7b7'), -- 2019-06-11 10:02:19.391640
('ffc449f0-8c2f-11e9-8f34-e03f49c7763b'), -- 2019-06-11 10:02:19.391640
('ffced5f0-8c2f-11e9-aba7-e03f497ffcbf'), -- 2019-06-11 10:02:19.460760
('ffd961f0-8c2f-11e9-96b4-e03f49d7f7bb'), -- 2019-06-11 10:02:19.529880
('ffe3edf0-8c2f-11e9-9bb8-e03f4977f7b7'), -- 2019-06-11 10:02:19.599000
('ffee79f0-8c2f-11e9-aba7-e03f497ffcbf'), -- 2019-06-11 10:02:19.668120
('fff905f0-8c2f-11e9-96b4-e03f49d7f7bb'), -- 2019-06-11 10:02:19.737240
('000391f0-8c30-11e9-aba7-e03f497ffcbf'), -- 2019-06-11 10:02:19.806360
('000e1df0-8c30-11e9-9bb8-e03f4977f7b7'), -- 2019-06-11 10:02:19.875480
('0018a9f0-8c30-11e9-96b4-e03f49d7f7bb'), -- 2019-06-11 10:02:19.944600
('002335f0-8c30-11e9-9bb8-e03f4977f7b7'), -- 2019-06-11 10:02:20.013720
('002dc1f0-8c30-11e9-aba7-e03f497ffcbf'), -- 2019-06-11 10:02:20.082840
('00384df0-8c30-11e9-96b4-e03f49d7f7bb'), -- 2019-06-11 10:02:20.151960
('0042d9f0-8c30-11e9-aba7-e03f497ffcbf'), -- 2019-06-11 10:02:20.221080
('004d65f0-8c30-11e9-9bb8-e03f4977f7b7')  -- 2019-06-11 10:02:20.290200
;

ANALYZE uuid_v1_operators;

SELECT
    count(*) FILTER (WHERE id < '002335f0-8c30-11e9-9bb8-e03f4977f7b7') AS count_lt,
    count(*) FILTER (WHERE id <= '002335f0-8c30-11e9-9bb8-e03f4977f7b7') AS count_le,
    count(*) FILTER (WHERE id > '002335f0-8c30-11e9-9bb8-e03f4977f7b7') AS count_gt,
    count(*) FILTER (WHERE id >= '002335f0-8c30-11e9-9bb8-e03f4977f7b7') AS count_ge
FROM uuid_v1_operators;

SELECT
    count(*) FILTER (WHERE id <~ '2019-06-11 10:02:20.013720') AS count_lt,
    count(*) FILTER (WHERE id <=~ '2019-06-11 10:02:20.013720') AS count_le,
    count(*) FILTER (WHERE id >~ '2019-06-11 10:02:20.013720') AS count_gt,
    count(*) FILTER (WHERE id >=~ '2019-06-11 10:02:20.013720') AS count_ge
FROM uuid_v1_operators;
