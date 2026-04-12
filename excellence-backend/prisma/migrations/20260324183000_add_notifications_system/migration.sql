CREATE TABLE IF NOT EXISTS "user_device_tokens" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "institute_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "token" TEXT NOT NULL UNIQUE,
  "platform" VARCHAR(20) NOT NULL,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "last_seen_at" TIMESTAMPTZ,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT "user_device_tokens_institute_id_fkey" FOREIGN KEY ("institute_id") REFERENCES "institutes"("id") ON DELETE CASCADE,
  CONSTRAINT "user_device_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS "user_device_tokens_institute_user_idx"
  ON "user_device_tokens"("institute_id", "user_id");
CREATE INDEX IF NOT EXISTS "user_device_tokens_institute_active_idx"
  ON "user_device_tokens"("institute_id", "is_active");

CREATE TABLE IF NOT EXISTS "notifications" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "title" VARCHAR(200) NOT NULL,
  "body" TEXT NOT NULL,
  "type" VARCHAR(30) NOT NULL,
  "role_target" VARCHAR(20),
  "user_id" UUID,
  "institute_id" UUID NOT NULL,
  "read_status" BOOLEAN NOT NULL DEFAULT false,
  "meta" JSONB,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT "notifications_institute_id_fkey" FOREIGN KEY ("institute_id") REFERENCES "institutes"("id") ON DELETE CASCADE,
  CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS "notifications_institute_created_idx"
  ON "notifications"("institute_id", "created_at");
CREATE INDEX IF NOT EXISTS "notifications_user_read_idx"
  ON "notifications"("user_id", "read_status");
CREATE INDEX IF NOT EXISTS "notifications_institute_role_target_idx"
  ON "notifications"("institute_id", "role_target");

CREATE TABLE IF NOT EXISTS "notification_delivery_logs" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "notification_id" UUID NOT NULL,
  "institute_id" UUID NOT NULL,
  "user_id" UUID,
  "token" TEXT,
  "status" VARCHAR(20) NOT NULL,
  "provider_message_id" VARCHAR(255),
  "error_message" TEXT,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT "notification_delivery_logs_notification_id_fkey" FOREIGN KEY ("notification_id") REFERENCES "notifications"("id") ON DELETE CASCADE,
  CONSTRAINT "notification_delivery_logs_institute_id_fkey" FOREIGN KEY ("institute_id") REFERENCES "institutes"("id") ON DELETE CASCADE,
  CONSTRAINT "notification_delivery_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS "notification_delivery_logs_notification_idx"
  ON "notification_delivery_logs"("notification_id");
CREATE INDEX IF NOT EXISTS "notification_delivery_logs_institute_status_idx"
  ON "notification_delivery_logs"("institute_id", "status");
