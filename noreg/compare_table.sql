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
    SELECT string_agg(
        quote_literal(column_name) || ' , jsonb_build_object( ' ||
        '    ''t1_value'', COALESCE(t1.' || quote_ident(column_name) || '::TEXT, ''NULL''), ' ||
        '    ''t2_value'', COALESCE(t2.' || quote_ident(column_name) || '::TEXT, ''NULL''), ' ||
        '    ''diff'', ' ||
        '    CASE ' ||
        '        WHEN t1.' || quote_ident(column_name) || ' IS NULL AND t2.' || quote_ident(column_name) || ' IS NULL THEN ''NULL'' ' ||
        '        WHEN t1.' || quote_ident(column_name) || ' = t2.' || quote_ident(column_name) || ' THEN ''MATCH'' ' ||
        '        ELSE ''DIFF'' ' ||
        '    END ' ||
        '    )'
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
                EXISTS (SELECT 1 FROM jsonb_each(jsonb_build_object(' || json_text || ')) 
                 WHERE value->>''diff'' = ''DIFF'') AS hasChanged,
                jsonb_build_object(' || json_text || ') AS changes
         FROM ' || quote_ident(table1_name) || ' t1
         FULL JOIN ' || quote_ident(table2_name) || ' t2 
         ON t1.ref_id = t2.ref_id
         ORDER BY t1.ref_id';

    -- ✅ Print the generated SQL query for debugging
    RAISE NOTICE 'Generated SQL: %', sql_query;

    -- Execute the dynamic query and return results
    RETURN QUERY EXECUTE sql_query;
END $$;
