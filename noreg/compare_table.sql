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
    json_build TEXT;
    sql_query TEXT;
BEGIN
    -- Generate the JSON structure dynamically, EXCLUDING 'id' and timestamps
    SELECT string_agg(
        '    ''' || column_name || ''': { ' ||
        '    ''t1_value'': ''' || COALESCE(''||t1.' || column_name || '::TEXT||', 'NULL') || ''', ' ||
        '    ''t2_value'': ''' || COALESCE(''||t2.' || column_name || '::TEXT||', 'NULL') || ''', ' ||
        '    ''diff'': ''' || 
        '    CASE ' ||
        '        WHEN t1.' || column_name || ' IS NULL AND t2.' || column_name || ' IS NULL THEN ''NULL'' ' ||
        '        WHEN t1.' || column_name || ' = t2.' || column_name || ' THEN ''MATCH'' ' ||
        '        ELSE ''DIFF'' ' ||
        '    END ' ||
        '    || '''' ' ||
        '    }'
    , ', ') INTO json_build
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE table_name = table1_name
    AND column_name NOT IN ('id', 'created_at', 'updated_at');  -- Exclude ID and timestamps

    -- Ensure column list is not empty
    IF json_build IS NULL THEN
        RAISE EXCEPTION 'No matching columns found in table %', table1_name;
    END IF;

    -- Construct the final dynamic SQL query
    sql_query := 
        'SELECT t1.ref_id::INT AS ref_id, 
                (SELECT COUNT(*) FROM jsonb_each((''{' || json_build || '}'')::jsonb) 
                 WHERE value->>''diff'' = ''DIFF'') > 0 AS hasChanged,
                (''{' || json_build || '}'')::jsonb AS changes
         FROM ' || table1_name || ' t1
         FULL JOIN ' || table2_name || ' t2 
         ON t1.ref_id = t2.ref_id
         ORDER BY t1.ref_id';

    -- Execute the dynamic query and return results
    RETURN QUERY EXECUTE sql_query;
END $$;
