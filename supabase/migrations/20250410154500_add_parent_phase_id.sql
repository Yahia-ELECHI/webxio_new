-- Add parent_phase_id column to phases table
ALTER TABLE "public"."phases" 
  ADD COLUMN "parent_phase_id" UUID REFERENCES "public"."phases"("id") ON DELETE CASCADE;

-- Add comment to column
COMMENT ON COLUMN "public"."phases"."parent_phase_id" IS 'ID of the parent phase, null for main phases';

-- Create index on parent_phase_id for better performance
CREATE INDEX "idx_phases_parent_phase_id" ON "public"."phases" ("parent_phase_id");

-- Update RLS policies to include parent_phase_id check
ALTER POLICY "Enable read access for authenticated users with permission" ON "public"."phases"
  USING (
    (SELECT user_has_permission(auth.uid(), 'read_phase', project_id, NULL))
    OR
    (parent_phase_id IS NOT NULL AND 
     (SELECT user_has_permission(auth.uid(), 'read_phase', 
                                (SELECT project_id FROM phases WHERE id = parent_phase_id), NULL))
    )
  );
