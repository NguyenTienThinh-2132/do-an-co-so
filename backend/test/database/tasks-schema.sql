-- TV3 schema test: all sample rows are rolled back.
\set ON_ERROR_STOP on
BEGIN;

DO $test$
DECLARE
  sample public.tasks%ROWTYPE;
BEGIN
  IF current_database() <> 'finai_tv3_demo' THEN
    RAISE EXCEPTION 'Tests must only run against finai_tv3_demo';
  END IF;

  INSERT INTO public.tasks (id, title, start_at, end_at)
  VALUES (
    '__tv3_schema_check__', 'Schema test',
    '2026-11-06T09:00:00+07', '2026-11-06T10:00:00+07'
  ) RETURNING * INTO sample;

  IF sample.priority <> 'medium' OR sample.status <> 'pending' THEN
    RAISE EXCEPTION 'Unexpected defaults';
  END IF;
  IF sample.description IS NOT NULL OR sample.category_id IS NOT NULL THEN
    RAISE EXCEPTION 'Optional fields must allow null';
  END IF;
  IF sample.start_at <> TIMESTAMPTZ '2026-11-06T02:00:00Z' THEN
    RAISE EXCEPTION 'Timezone instant mismatch';
  END IF;
  RAISE NOTICE 'PASS: valid insert, defaults, nullable fields and timezone instant';

  BEGIN
    INSERT INTO public.tasks (id, title, start_at, end_at)
    VALUES ('__bad_title__', E' \t\n\r', now(), now() + interval '1 hour');
    RAISE EXCEPTION 'Blank title was accepted';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: whitespace-only title rejected';
  END;

  BEGIN
    INSERT INTO public.tasks (id, title, start_at, end_at)
    VALUES ('__bad_equal_time__', 'Test', now(), now());
    RAISE EXCEPTION 'Equal times were accepted';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: equal start/end rejected';
  END;

  BEGIN
    INSERT INTO public.tasks (id, title, start_at, end_at)
    VALUES ('__bad_reverse_time__', 'Test', now(), now() - interval '1 hour');
    RAISE EXCEPTION 'Reversed times were accepted';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: reversed start/end rejected';
  END;

  BEGIN
    INSERT INTO public.tasks (id, title, start_at, end_at, priority)
    VALUES ('__bad_priority__', 'Test', now(), now() + interval '1 hour', 'urgent');
    RAISE EXCEPTION 'Invalid priority was accepted';
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE NOTICE 'PASS: invalid priority rejected';
  END;

  BEGIN
    INSERT INTO public.tasks (id, title, start_at, end_at, status)
    VALUES ('__bad_status__', 'Test', now(), now() + interval '1 hour', 'overdue');
    RAISE EXCEPTION 'Invalid status was accepted';
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE NOTICE 'PASS: overdue is not a stored status';
  END;

  BEGIN
    INSERT INTO public.tasks (id, title, start_at, end_at)
    VALUES ('__tv3_schema_check__', 'Duplicate', now(), now() + interval '1 hour');
    RAISE EXCEPTION 'Duplicate ID was accepted';
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'PASS: duplicate ID rejected';
  END;
END
$test$;

ROLLBACK;
SELECT count(*) AS task_rows_after_rollback FROM public.tasks;
