SET timezone TO 'Zulu';
\x

-- I/O
SELECT 'edb4d8f0-1a80-11e8-98d9-e03f49f7f8f3'::uuid_v1 AS ext;
SELECT '86D50AF6-F95C-11EB-ADF0-9D8BA2D04971'::uuid_v1 AS ext_upper;
SELECT '{ab16b0c2-f95c-11eb-adf0-9d8ba2d04971}'::uuid_v1 AS ext_braces;
SELECT 'b367f704f95c11ebadf09d8ba2d04971'::uuid_v1 AS ext_nosep;
SELECT '{bfe86f04f95c11ebadf09d8ba2d04971}'::uuid_v1 AS ext_nosep_braces;
SELECT '.~([ 0082ZR56baPf95d_11eb/adf0 9d8ba2___d04971 ])~.'::uuid_v1 AS ext_skip_garbage;

-- ...don't accept garbage...
SELECT 'd1b1c622-f95c-11eb-adf0-9d8_a2d04971'::uuid_v1 AS fail;

-- ...don't accept different versions...
SELECT '87c771ce-bc95-3114-ae59-c0e26acf8e81'::uuid_v1 AS ver_3;
SELECT '22859369-3a4f-49ef-8264-1aaf0a953299'::uuid_v1 AS ver_4;
SELECT 'c9aec822-6992-5c93-b34a-33cc0e952b5e'::uuid_v1 AS ver_5;
SELECT '00000000-0000-0000-0000-000000000000'::uuid_v1 AS nil;

-- ...don't accept different variants...
SELECT 'edb4d8f0-1a80-11e8-78d9-e03f49f7f8f3'::uuid_v1 AS var_ncs;
SELECT 'edb4d8f0-1a80-11e8-d8d9-e03f49f7f8f3'::uuid_v1 AS var_ms;
SELECT 'edb4d8f0-1a80-11e8-f8d9-e03f49f7f8f3'::uuid_v1 AS var_future;
