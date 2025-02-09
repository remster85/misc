NOTICE:  Generated SQL Query: 
SELECT t1.ref_id::INT AS ref_id, 
       EXISTS (SELECT 1 FROM jsonb_each(('{"account_id": { "t1_value": "123", "t2_value": "124", "diff": "DIFF"}, "name": { "t1_value": "Alice", "t2_value": "Alice", "diff": "MATCH"}}'::jsonb)) 
               WHERE value->>'diff' = 'DIFF') > 0 AS hasChanged,
       ('{"account_id": { "t1_value": "123", "t2_value": "124", "diff": "DIFF"}, "name": { "t1_value": "Alice", "t2_value": "Alice", "diff": "MATCH"}}'::jsonb) AS changes
FROM table1 t1
FULL JOIN table2 t2 
ON t1.ref_id = t2.ref_id
ORDER BY t1.ref_id;
