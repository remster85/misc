CREATE OR REPLACE FUNCTION compare_tables(
    table1_name TEXT, 
    table2_name TEXT
)
RETURNS TABLE (
    ref_id INT, 
    hasChanged BOOLEAN, 
    changes JSONB
) 
LANGUAGE plpgsql
AS $$
DECLARE
    json_text TEXT;
    sql_query TEXT;
BEGIN
    -- Generate JSON dynamically, EXCLUDING 'id' and timestamps
    SELECT STRING_AGG(
        '"' || column_name || '": {' ||
        '"t1_value": "' || COALESCE(''|| quote_ident('t1') || '.' || quote_ident(column_name) || '::TEXT', '''NULL''') || '", ' ||
        '"t2_value": "' || COALESCE(''|| quote_ident('t2') || '.' || quote_ident(column_name) || '::TEXT', '''NULL''') || '", ' ||
        '"diff": "' ||
        ' CASE ' ||
        ' WHEN ' || quote_ident('t1') || '.' || quote_ident(column_name) || ' IS NULL AND ' || quote_ident('t2') || '.' || quote_ident(column_name) || ' IS NULL THEN ''NULL'' ' ||
        ' WHEN ' || quote_ident('t1') || '.' || quote_ident(column_name) || ' = ' || quote_ident('t2') || '.' || quote_ident(column_name) || ' THEN ''MATCH'' ' ||
        ' ELSE ''DIFF'' ' ||
        ' END || '" }"' 
    , ', ') INTO json_text
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE table_name = table1_name
    AND column_name NOT IN ('id', 'created_at', 'updated_at');  -- Exclude ID and timestamps

    -- Ensure column list is not empty
    IF json_text IS NULL THEN
        RAISE EXCEPTION 'No matching columns found in table %', table1_name;
    END IF;

    -- Construct the final dynamic SQL query
    sql_query := 
        'SELECT t1.ref_id::INT AS ref_id, 
                EXISTS (SELECT 1 FROM jsonb_each((''{' || json_text || '}''::jsonb)) 
                 WHERE value->>''diff'' = ''DIFF'') AS hasChanged,
                (''{' || json_text || '}''::jsonb) AS changes
         FROM ' || quote_ident(table1_name) || ' t1
         FULL JOIN ' || quote_ident(table2_name) || ' t2 
         ON t1.ref_id = t2.ref_id
         ORDER BY t1.ref_id';

    -- ✅ Print the generated SQL query before execution
    RAISE NOTICE 'Generated SQL Query: %', sql_query;

    -- Execute the dynamic query and return results
    RETURN QUERY EXECUTE sql_query;
END $$;
