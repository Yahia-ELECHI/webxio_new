-- Add sub_phase_id column to tasks table
ALTER TABLE "public"."tasks" 
  ADD COLUMN "sub_phase_id" UUID REFERENCES "public"."phases"("id") ON DELETE SET NULL;

-- Add comment to column
COMMENT ON COLUMN "public"."tasks"."sub_phase_id" IS 'ID of the sub-phase, null if the task is directly associated with a main phase';

-- Create index on sub_phase_id for better performance
CREATE INDEX "idx_tasks_sub_phase_id" ON "public"."tasks" ("sub_phase_id");

-- Add constraint to ensure sub_phase_id belongs to a sub-phase that is a child of the main phase
ALTER TABLE "public"."tasks"
  ADD CONSTRAINT "sub_phase_belongs_to_main_phase" 
  CHECK (
    sub_phase_id IS NULL OR 
    (SELECT parent_phase_id FROM phases WHERE id = sub_phase_id) = phase_id
  );

-- Update RLS policies to include sub_phase_id check in task permissions
ALTER POLICY "Enable read access for authenticated users with permission" ON "public"."tasks"
  USING (
    (SELECT user_has_permission(auth.uid(), 'read_task', project_id, NULL))
    OR
    (sub_phase_id IS NOT NULL AND 
     (SELECT user_has_permission(auth.uid(), 'read_task', 
                               (SELECT project_id FROM phases WHERE id = sub_phase_id), NULL))
    )
  );
