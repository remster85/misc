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
    -- Generate the dynamic JSON comparison, EXCLUDING 'id' and timestamps
    SELECT string_agg(
        format(
            '''%I'', jsonb_build_object(
                ''%I_t1'', t1.%I::TEXT, 
                ''%I_t2'', t2.%I::TEXT, 
                ''%I_diff'', 
                CASE 
                    WHEN t1.%I IS NULL AND t2.%I IS NULL THEN ''NULL'' 
                    WHEN t1.%I = t2.%I THEN ''MATCH'' 
                    ELSE ''DIFF'' 
                END
            )',
            column_name, column_name, column_name, 
            column_name, column_name, 
            column_name, column_name, column_name, 
            column_name, column_name
        ), ', '
    ) INTO json_build
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE table_name = table1_name
    AND column_name NOT IN ('id', 'created_at', 'updated_at');  -- Exclude ID and timestamps

    -- Ensure column list is not empty
    IF json_build IS NULL THEN
        RAISE EXCEPTION 'No matching columns found in table %', table1_name;
    END IF;

    -- Construct final dynamic query
    sql_query := format(
        'SELECT t1.ref_id::INT AS ref_id, 
                EXISTS (SELECT 1 FROM jsonb_each(jsonb_build_object(%s)) WHERE value->>''%s_diff'' = ''DIFF'') AS hasChanged,
                jsonb_build_object(%s) AS changes
         FROM %I t1
         FULL JOIN %I t2 ON t1.ref_id = t2.ref_id
         ORDER BY t1.ref_id',
        json_build,  -- JSON difference builder
        table1_name, -- Dynamic table name for column diff check
        json_build,  -- JSON object construction
        table1_name, table2_name
    );

    -- Execute the dynamic query and return results
    RETURN QUERY EXECUTE sql_query;
END $$;
