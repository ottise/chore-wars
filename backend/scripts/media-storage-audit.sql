-- Read-only: attachment age, durable bytes and missing legacy attach markers.
-- Does not select file contents or user messages. A missing database blob may
-- still exist on the old service disk; verify before declaring it unrecoverable.
SELECT m."CreatedAt"::date AS upload_day,
       count(*) AS attachments,
       count(f."StorageKey") AS durable_blobs,
       count(*) FILTER (WHERE m."AttachedAt" IS NULL) AS without_attach_marker,
       count(*) FILTER (WHERE EXISTS (
           SELECT 1 FROM "ChatMessages" c WHERE c."AttachmentId" = m."Id"
       )) AS referenced_by_message,
       count(*) FILTER (WHERE f."StorageKey" IS NULL AND EXISTS (
           SELECT 1 FROM "ChatMessages" c WHERE c."AttachmentId" = m."Id"
       )) AS sent_without_durable_blob
FROM "MediaAttachments" m
LEFT JOIN "PrivateMediaFiles" f ON f."StorageKey" = m."StorageKey"
GROUP BY 1 ORDER BY 1;
