-- This is default tarantool initialization file
-- with easy to use configuration examples including
-- replication, sharding and all major features
-- Complete documentation available in:  http://tarantool.org/doc/
--
-- To start this instance please run `systemctl start tarantool@example` or
-- use init scripts provided by binary packages.
-- To connect to the instance, use "sudo tarantoolctl enter example"
-- Features:
-- 1. Database configuration
-- 2. Binary logging and automatic checkpoints
-- 3. Replication
-- 4. Automatinc sharding
-- 5. Message queue
-- 6. Data expiration

local shard2 = require('shard')
local json = require('json')

-----------------
-- Configuration
-----------------
box.cfg {
    ------------------------
    -- Network configuration
    ------------------------

    -- The read/write data port number or URI
    -- Has no default value, so must be specified if
    -- connections will occur from remote clients
    -- that do not use “admin address”
    listen = '0.0.0.0:4301';
    -- listen = '*:3301';

    -- The server is considered to be a Tarantool replica
    -- it will try to connect to the master
    -- which replication_source specifies with a URI
    -- for example konstantin:secret_password@tarantool.org:3301
    -- by default username is "guest"
    -- replication_source="127.0.0.1:3102";

    --replication = { 'tnt:tnt@192.168.1.45:3301',
    --                'tnt:tnt@192.168.1.152:3302'};

    read_only = false;

    -- The server will sleep for io_collect_interval seconds
    -- between iterations of the event loop
    io_collect_interval = nil;

    -- The size of the read-ahead buffer associated with a client connection
    readahead = 16320;

    ----------------------
    -- Memtx configuration
    ----------------------

    -- An absolute path to directory where snapshot (.snap) files are stored.
    -- If not specified, defaults to /var/lib/tarantool/INSTANCE
    -- memtx_dir = nil;

    -- How much memory Memtx engine allocates
    -- to actually store tuples, in bytes.
    memtx_memory = 2048 * 1024 * 1024; -- 128Mb

    -- Size of the smallest allocation unit, in bytes.
    -- It can be tuned up if most of the tuples are not so small
    memtx_min_tuple_size = 16;

    -- Size of the largest allocation unit, in bytes.
    -- It can be tuned up if it is necessary to store large tuples
    memtx_max_tuple_size = 128 * 1024 * 1024; -- 128Mb

    -- Reduce the throttling effect of box.snapshot() on
    -- INSERT/UPDATE/DELETE performance by setting a limit
    -- on how many megabytes per second it can write to disk
    -- memtx_snap_io_rate_limit = nil;

    ----------------------
    -- Vinyl configuration
    ----------------------

    -- An absolute path to directory where Vinyl files are stored.
    -- If not specified, defaults to /var/lib/tarantool/INSTANCE
    -- vinyl_dir = nil;

    -- How much memory Vinyl engine can use for in-memory level, in bytes.
    vinyl_memory = 2048 * 1024 * 1024; -- 128Mb

    -- How much memory Vinyl engine can use for caches, in bytes.
    vinyl_cache = 128 * 1024 * 1024; -- 128Mb

    -- Size of the largest allocation unit, in bytes.
    -- It can be tuned up if it is necessary to store large tuples
    vinyl_max_tuple_size = 128 * 1024 * 1024; -- 128Mb

    -- The maximum number of background workers for compaction.
    vinyl_write_threads = 2;

    ------------------------------
    -- Binary logging and recovery
    ------------------------------

    -- An absolute path to directory where write-ahead log (.xlog) files are
    -- stored. If not specified, defaults to /var/lib/tarantool/INSTANCE
    -- wal_dir = nil;

    -- Specify fiber-WAL-disk synchronization mode as:
    -- "none": write-ahead log is not maintained;
    -- "write": fibers wait for their data to be written to the write-ahead log;
    -- "fsync": fibers wait for their data, fsync follows each write;
    wal_mode = "write";

    -- The maximal size of a single write-ahead log file
    wal_max_size = 1024 * 1024 * 1024;

    -- The interval between actions by the checkpoint daemon, in seconds
    checkpoint_interval = 60 * 60; -- one hour

    -- The maximum number of checkpoints that the daemon maintans
    checkpoint_count = 6;

    -- Don't abort recovery if there is an error while reading
    -- files from the disk at server start.
    force_recovery = true;

    ----------
    -- Logging
    ----------

    -- How verbose the logging is. There are six log verbosity classes:
    -- 1 – SYSERROR
    -- 2 – ERROR
    -- 3 – CRITICAL
    -- 4 – WARNING
    -- 5 – INFO
    -- 6 – VERBOSE
    -- 7 – DEBUG
    log_level = 5;

    -- By default, the log is sent to /var/log/tarantool/INSTANCE.log
    -- If logger is specified, the log is sent to the file named in the string
    -- logger = "example.log";

    -- If true, tarantool does not block on the log file descriptor
    -- when it’s not ready for write, and drops the message instead
    --log_nonblock = true;

    -- If processing a request takes longer than
    -- the given value (in seconds), warn about it in the log
    too_long_threshold = 0.5;

    -- Inject the given string into server process title
    -- custom_proc_title = 'example';
}

local function bootstrap2()
    function mod_insert(space_to_insert, tuple)
        space = box.space[space_to_insert]
        tup = space:auto_increment(tuple)
        return tup[1]
    end
    function mod_len(space)
        return box.space[space]:len()
    end
    function mod_search(space_to_search, index, value, iter, lim)
        space = box.space[space_to_search]
        res = space.index[index]:select({value}, {iterator = iter, limit = lim})
        return res
    end

    game = box.schema.space.create('game', {if_not_exists = true})
    game:create_index('primary', {type = 'tree', unique = true, if_not_exists = true, parts = {1, 'unsigned'}}) -- Column id
    game:create_index('name', {type = 'tree', if_not_exists = true, parts = {{2, 'string', collation = 'unicode_ci'}}}) -- Column Name, it's unique
    -- Column Logo we're not indexing          3
    -- Column Description we're not indexing   4
    game:format({
                   {name='id', type='unsigned'},
                   {name='name', type='string'},
                   {name='logo', type='string'},
                   {name='description', type='string'},
               })


    -- Create PLAYER space
    player = box.schema.space.create('player', {if_not_exists = true})
    player:create_index('primary', {type = 'tree', unique = true, if_not_exists = true, parts = {1, 'unsigned'}}) -- Column id
    player:create_index('name', {type = 'tree', unique = true, if_not_exists = true, parts = {{2, 'string', collation = 'unicode_ci'}}}) -- Column Name, it's unique
    -- Column Description we're not indexing   3
    -- Column Logo we're not indexing          4
    player:create_index('rating', {type = 'tree', unique = false,  if_not_exists = true, parts = {5, 'unsigned'}}) -- Column Rating_global, it's not unique
    player:create_index('id_game', {type = 'tree', unique = false, if_not_exists = true, parts = {6, 'unsigned'}}) -- Column id_game, that's id of game whose player is play
    player:create_index('id_team', {type = 'tree', unique = false, if_not_exists = true, parts = {7, 'unsigned'}}) -- Column id_team, that's id of team whose player is play; if == 1, Player doesn't exist in any team
    player:format({
                   {name='id', type='unsigned'},
                   {name='name', type='string'},
                   {name='description', type='string'},
                   {name='logo', type='string'},
                   {name='rating', type='unsigned'},
                   {name='id_game', type='unsigned'},
                   {name='id_team', type='unsigned'},
               })


    -- Create TEAM space
    team = box.schema.space.create('team', {if_not_exists = true})
    team:create_index('primary', {type = 'tree', unique = true, if_not_exists = true, parts = {1, 'unsigned'}}) -- Column id
    team:create_index('name', {type = 'tree', unique = true, if_not_exists = true, parts = {{2, 'string', collation = 'unicode_ci'}}}) -- Column Name, it's unique
    -- Column Description we're not indexing   3
    -- Column Logo we're not indexing          4
    team:create_index('rating', {type = 'tree', unique = false, if_not_exists = true, parts = {5, 'unsigned'}}) -- Column Rating_global, it's not unique
    team:create_index('id_game', {type = 'tree', unique = false, if_not_exists = true, parts = {6, 'unsigned'}}) -- Column id_game, that's id of game whose team is play
    team:format({
                   {name='id', type='unsigned'},
                   {name='name', type='string'},
                   {name='description', type='string'},
                   {name='logo', type='string'},
                   {name='rating', type='unsigned'},
                   {name='id_game', type='unsigned'},
               })


    -- Create TEAM_MATCH space
    team_match = box.schema.space.create('team_match', {if_not_exists = true})
    team_match:create_index('primary', {type = 'tree', unique = true, if_not_exists = true, parts = {1, 'unsigned'}}) -- Column id
    team_match:create_index('id_team', {type = 'tree', unique = false, if_not_exists = true, parts = {2, 'unsigned'}}) -- Column id_team
    --box.space.team_match:create_index('add', {type = 'rtree', if_not_exists = true, parts = {3, 'array'}}) -- Column add with ID's of players whose added to team on match
    --box.space.team_match:create_index('del', {type = 'rtree', if_not_exists = true, parts = {4, 'array'}}) -- Column add with ID's of players whose deleted in team on match
    team_match:create_index('id_match', {type = 'tree', unique = false, if_not_exists = true, parts = {5, 'unsigned'}}) -- Column id_match, that's id of match which team is play
    team_match:format({
                   {name='id', type='unsigned'},
                   {name='id_team', type='unsigned'},
                   {name='add', type='array'},
                   {name='del', type='array'},
                   {name='id_match', type='unsigned'},
               })


    -- Keep things safe by default
    box.schema.user.create('tnt', { password = 'tnt', if_not_exists = true })
    -- box.schema.user.grant('example', 'replication')
    box.schema.user.grant('tnt', 'read,write,execute', 'universe', nil, {if_not_exists = true})

    print("box.once is executed on master")
end

-- for first run create a space and add set up grants
box.once('SHARD-2-MASTER-', bootstrap2)

-----------------------
-- Automatinc sharding
-----------------------
-- N.B. you need install tarantool-shard package to use shadring
-- Docs: https://github.com/tarantool/shard/blob/master/README.md
-- Example:
shard2.init {
    servers = {
        { uri = [[0.0.0.0:4302]]; zone = [[0]]; };
        { uri = [[0.0.0.0:4301]]; zone = [[1]]; };
	{ uri = [[0.0.0.0:3301]]; zone = [[2]]; };
	{ uri = [[0.0.0.0:3302]]; zone = [[3]]; };
    };
    login = 'tnt';
    password = 'tnt';
    redundancy = 2;
    binary = '0.0.0.0:4301';
    monitor = false;
    replication = true;
}

shard2.game:insert({1, 'Dota 2', '/static/img/logo/int12.png', "That's most popular online game"})
print(json.encode(shard2.game:select({1})))

-----------------
-- Message queue
-----------------
-- N.B. you need to install tarantool-queue package to use queue
-- Docs: https://github.com/tarantool/queue/blob/master/README.md
-- Example:
queue = require('queue')
queue.create_tube('shard2_queue', 'fifottl', {temporary = true})

-------------------
-- Data expiration
-------------------
-- N.B. you need to install tarantool-expirationd package to use expirationd
-- Docs: https://github.com/tarantool/expirationd/blob/master/README.md
-- Example (deletion of all tuples):
--  local expirationd = require('expirationd')
--  local function is_expired(args, tuple)
--    return true
--  end
--  expirationd.start("clean_all", space.id, is_expired {
--    tuple_per_item = 50,
--    full_scan_time = 3600
--  })