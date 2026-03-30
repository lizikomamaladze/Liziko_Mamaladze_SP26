-- 1. 
-- Created a large test table with 10 million rows using generate_series.
-- Each row contains a long string to simulate real storage usage.
 
 CREATE TABLE table_to_delete AS
               SELECT 'veeeeeeery_long_string' || x AS col
               FROM generate_series(1,(10^7)::int) x; 
-- Took 33 seconds to create. 
 
 
-------------------------------------------------------------------------------------------------
-- 2.
-- Check how much disk space the table uses before any operations
-- Includes total size, table data, indexes, and TOAST storage
 
  SELECT *, pg_size_pretty(total_bytes) AS total,
                                    pg_size_pretty(index_bytes) AS INDEX,
                                    pg_size_pretty(toast_bytes) AS toast,
                                    pg_size_pretty(table_bytes) AS TABLE
               FROM ( SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
                               FROM (SELECT c.oid,nspname AS table_schema,
                                                               relname AS TABLE_NAME,
                                                              c.reltuples AS row_estimate,
                                                              pg_total_relation_size(c.oid) AS total_bytes,
                                                              pg_indexes_size(c.oid) AS index_bytes,
                                                              pg_total_relation_size(reltoastrelid) AS toast_bytes
                                              FROM pg_class c
                                              LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
                                              WHERE relkind = 'r'
                                              ) a
                                    ) a
               WHERE table_name LIKE '%table_to_delete%';

 -- Before performing any operations, the table table_to_delete occupied 
 -- approximately 575 MB, with almost all space used by table data 
 -- and little space from TOAST and no space from index size. 
  
  
 --------------------------------------------------------------------------------------------
 -- 3. 
 -- removes 1/3 of all rows
  DELETE FROM table_to_delete
               WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0; 
 
-- a) The DELETE operation took approximately 15 seconds to remove 
--    about one-third of the table (3.3 million rows).
 
-- b) After performing the DELETE operation, and runing the query to check disk space,
--    the table size remained same 575 MB, indicating that disk space was not freed up, 
--    even though about one-third of the rows were deleted.  
 
-- c) 
   VACUUM FULL VERBOSE table_to_delete;
-- The VACUUM FULL operation completed successfully and took 
-- approximately 13 seconds to reorganize the table and remove dead tuples.

-- d) 
-- After running VACUUM FULL, I expected the table size to decrease significantly,
-- but it remained approximately the same (~575 MB). However, when checking the
-- total_bytes value more precisely, I noticed a small decrease 
-- (from 602,611,712 bytes to 602,456,064 bytes).
--
-- This shows that VACUUM FULL did free up some space by removing dead tuples,
-- but the change is not very noticeable in MB because each row in the table is small.

-- After researching how PostgreSQL stores data, I found that it uses fixed-size
-- pages (typically 8KB blocks). Data is stored inside these pages, and even if
-- some rows are removed, the page itself still exists unless it becomes completely empty.
--
-- I also looked into TOAST storage, which is used for large values. While in this
-- case TOAST usage is minimal, its structure and allocated pages may still remain
-- even after data is removed, contributing to why the overall table size does not
-- shrink significantly.

-- Additionally, when I ran the size query second time after VACUUM FULL,
-- I observed slightly different total_bytes values. This is likely because
-- PostgreSQL each time tries to execute the VACUUM command better as the
-- data is updated after each command so later queries
-- may reflect a more accurate measurement of the table size.

-- In conclusion, VACUUM FULL works correctly and reclaims space, but the visible
-- reduction depends on data size, page structure, and how storage is managed

-- e)
DROP TABLE IF EXISTS table_to_delete;
-- Non reversible command to remove entire database and it's daa. to recreate it. Took 1.215 seconds.
CREATE TABLE table_to_delete AS
SELECT 'veeeeeery_long_string' || x AS col
FROM generate_series(1, (10^7)::int) x;
-- Recreated the table with 10 milion rows and took 32 seconds.


--------------------------------------------------------------------------------------------------
 -- 4.
TRUNCATE table_to_delete;
 
-- a) The TRUNCATE operation took approximately 1.211 seconds

-- b), c) 
-- Execution time:
-- From my testing, DELETE took around 15 seconds, while TRUNCATE took about 1.2 seconds.
-- After examining this behavior and researching it, I know that DELETE scans
-- and processes each row individually, which makes it slower for larger datasets.
-- TRUNCATE, on the other hand, does not scan rows at all and simply resets the table,
-- which explains why it is significantly faster.

-- Disk space usage:
-- DELETE does not immediately free disk space because PostgreSQL uses MVCC,
-- meaning deleted rows are only marked as dead tuples and still occupy storage,
-- so it does not interfere when multiple users access and modify data at the same time.
-- Even after running VACUUM FULL, the reduction in size was minimal in this case.
-- As I mentioned earlier this happens because, PostgreSQL stores data in fixed-size
-- pages, so unless entire pages are freed, the table size does not shrink much.
-- In contrast, TRUNCATE removes all data at once and releases the storage immediately,
-- reducing the table to its minimal size (one page – 8 KB), so it is not MVCC-safe,
-- meaning, effect is visible to other transactions instantly.

-- Transaction behavior:
-- DELETE is fully transactional and logs each row deletion in detail,
-- which makes it safer but slower.
-- TRUNCATE is also transactional in PostgreSQL, but it behaves differently:
-- instead of logging each row, it performs one big operation that resets the table.


-- Rollback possibility:
-- Both DELETE and TRUNCATE operations cannot be undone after COMMIT.
-- However, before commit, both can be Rolled back, however, 
-- DELETE is more flexible because it tracks row-level changes, 
-- while TRUNCATE performs one huge operation that
-- removes all data at once without tracking individual rows.


-----------------------------------------------------------------------------------------------
-- 5)
-- a) Space consumption
--    Before any operation - ~575 MB
--    After DELETE - ~575 MB (no significant change)
--    After VACUUM FULL - slight decrease (from 602,611,712 to 602,456,064 bytes)
--    After TRUNCATE - 8192 bytes (big decrease)

-- b) Already explained in 4. - b),c)

-- c) 
-- DELETE does not free space immediately because PostgreSQL uses MVCC,
-- where deleted rows are marked as dead tuples but still remain in storage.

-- VACUUM FULL changes table size, because it reclaims unused space (dead tuples)
-- and optimizes the performance of a database. Explained why it freed up little
-- space inthis case, above. 

-- TRUNCATE behaves differently because it removes all rows at once and
-- resets the table storage, without scanning individual rows, this makes
-- it much faster and immediately frees disk space.

-- These operations affect performance and storage differently - 
-- DELETE is slower and keeps unused space until cleanup,
-- while TRUNCATE is faster and more space-efficient but less flexible.



