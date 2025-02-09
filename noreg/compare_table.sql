CREATE OR REPLACE FUNCTION compare_tables(
    table1_name TEXT, 
    table2_name TEXT
)
RETURNS TABLE (
    ref_id INT, 
    column_differences TEXT
) 
LANGUAGE plpgsql
AS $$
DECLARE
    col_list TEXT;
    sql_query TEXT;
BEGIN
    -- Generate the dynamic column comparison list, EXCLUDING columns named 'id'
    SELECT string_agg(
        format(
            'CASE 
                WHEN t1.%I IS NULL AND t2.%I IS NULL THEN ''%I: NULL'' 
                WHEN t1.%I = t2.%I THEN ''%I: MATCH'' 
                ELSE ''%I: DIFF ('' || COALESCE(t1.%I::TEXT, ''NULL'') || '' → '' || COALESCE(t2.%I::TEXT, ''NULL'') || '')'' 
             END', 
            column_name, column_name, column_name, 
            column_name, column_name, column_name, 
            column_name, column_name, column_name
        ), 
        ' || '','' || '
    ) INTO col_list
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE table_name = table1_name
    AND column_name NOT IN ('id', 'created_at', 'updated_at');  -- Exclude ID and timestamp columns

    -- Ensure column list is not empty to avoid SQL errors
    IF col_list IS NULL THEN
        RAISE EXCEPTION 'No matching columns found in table %', table1_name;
    END IF;

    -- Build the final query, using only ref_id for joining
    sql_query := format(
        'SELECT t1.ref_id::INT AS ref_id, %s AS column_differences
         FROM %I t1
         FULL JOIN %I t2 ON t1.ref_id = t2.ref_id
         ORDER BY t1.ref_id', col_list, table1_name, table2_name
    );

    -- Execute the dynamic query and return results
    RETURN QUERY EXECUTE sql_query;
END $$;
