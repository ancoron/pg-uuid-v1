SET timezone TO 'Zulu';
\x

-- basic comparison method
SELECT
    uuid_v1_cmp('8385ded2-8dbb-11e9-ae2b-db6f0f573554', '8385ded2-8dbb-11e9-ae2b-db6f0f573554') AS eq,
    uuid_v1_cmp('8385ded2-8dbb-11e9-ae2b-db6f0f573554', '8385ded3-8dbb-11e9-ae2b-db6f0f573554') AS lt,
    uuid_v1_cmp('8385ded3-8dbb-11e9-ae2b-db6f0f573554', '8385ded2-8dbb-11e9-ae2b-db6f0f573554') AS gt,
    uuid_v1_cmp('8385ded2-8dbb-11e9-ae2b-db6f0f573554', '8385ded2-8dbb-11e9-ae2c-db6f0f573554') AS lt_clock,
    uuid_v1_cmp('8385ded2-8dbb-11e9-ae2c-db6f0f573554', '8385ded2-8dbb-11e9-ae2b-db6f0f573554') AS gt_clock,
    uuid_v1_cmp('8385ded2-8dbb-11e9-ae2b-db6f0f573554', '8385ded2-8dbb-11e9-ae2b-db6f0f573555') AS lt_node,
    uuid_v1_cmp('8385ded2-8dbb-11e9-ae2b-db6f0f573555', '8385ded2-8dbb-11e9-ae2b-db6f0f573554') AS gt_node
;
