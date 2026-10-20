-- Read-only checks before deploying the non-AI migrations.
-- Any rows in the duplicate reports require an explicit data repair decision.
SELECT "OccurrenceId", count(*) FROM "PaymentObligations"
WHERE "Reason" = 'FORCED_REASSIGNMENT' AND "OccurrenceId" IS NOT NULL
GROUP BY "OccurrenceId" HAVING count(*) > 1;
SELECT "ReferenceId", "Type", count(*) FROM "KarmaTransactions"
WHERE "ReferenceId" IS NOT NULL AND "Type" IN ('CHORE_COMPLETED','BONUS')
GROUP BY "ReferenceId", "Type" HAVING count(*) > 1;
SELECT "ChoreOccurrenceId", count(*) FROM "ChoreBounties"
WHERE "Status" IN ('OPEN','CLAIMED') GROUP BY "ChoreOccurrenceId" HAVING count(*) > 1;
SELECT "SeasonId", "UserId", count(*) FROM "SeasonRankings" GROUP BY "SeasonId", "UserId" HAVING count(*) > 1;
SELECT "AchievementId", "UserId", count(*) FROM "UserAchievements" GROUP BY "AchievementId", "UserId" HAVING count(*) > 1;
-- Existing zero snapshots are not rewritten from today's template values.
SELECT "Id", "SeasonId", "ChoreId", "SnapshotKarma" FROM "ChoreOccurrences" WHERE "SnapshotKarma" = 0;
