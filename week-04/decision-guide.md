# Week 4 — Storage and database decision guide

Everything in this lab was in `us-east-1` and was deleted the same day. The property SQL dump stayed on my machine and was not committed.

| Service | Use this when |
|---|---|
| S3 | The data is a file, not a disk. Store it in a bucket and use a lifecycle rule to move older objects to a cheaper storage class. |
| EBS | One EC2 instance needs its own disk, such as the root volume on the Week 3 PropertyLite server. |
| EFS | Several EC2 instances need to read and write the same files at the same time. |
| RDS | The data is relational and you need SQL, a fixed schema, and joins. |
| DynamoDB | You look up items by one key and do not want to run a database server. |

## What I used each one for

**S3.** I created `henry-idx-training-week04` and uploaded `week-03/runbook.md`. A lifecycle rule named `archive-after-30-days` was set to move every object to Glacier Flexible Retrieval after 30 days. Standard is the class for files you read immediately. Glacier Flexible Retrieval is the cheap archive class, and getting an object back takes minutes to hours. I deleted the object and the bucket while the file was still Standard, because Glacier has a 90-day minimum storage charge.

**EBS.** I did not add a new data disk this week. The temporary MySQL client, `rds-client`, had a 20 GiB gp3 root volume, and that volume was deleted with the instance. EBS is the Week 3 root disk: one volume attached to one instance.

**EFS.** I did not create a file system. EFS is the shared network drive you would add if the Week 6 Auto Scaling instances all needed the same files. S3 is a better fit for the runbook, because nothing needed to mount it.

**RDS.** I created `training-db`, a single-AZ MySQL 8.4 instance (`db.t4g.micro`, 20 GiB, Free tier template), with public access off. MySQL 8.4 still has `ROW_NUMBER()`, which the ID remap needs. I did not use 8.0, because standard support for 8.0 ended on July 31, 2026, and Extended Support is a per-vCPU charge. Multi-AZ would add a standby in a second availability zone. The Free tier template does not include it, and this lab did not need failover.

The database had no public IP, so I reached it from `rds-client` in the same default VPC. The first connection timed out. `training-db-sg` allowed port 3306 only from my home IP, which could never match a private database. The fix was an inbound rule whose source was the EC2 security group, `launch-wizard-1`, not an IP address. I imported the property dump, dropped the personal and address columns, and replaced the real listing IDs with synthetic IDs that start with `R1`.

**DynamoDB.** I created an on-demand table named `Properties`. The partition key is `L_ListingID` (a string), which is how DynamoDB finds one item. `PAY_PER_REQUEST` means there is no capacity to plan. I billed per read and write. I stored one cleaned row and read it back with `get-item`.

## Cleanup

I deleted `training-db` with no final snapshot and no retained automated backups, terminated `rds-client`, confirmed the volume was gone, deleted the DynamoDB table, and removed the S3 object and bucket. `training-db-sg` and `launch-wizard-1` were deleted after those resources were gone. The VPC default security group is still there, because AWS does not allow that one to be deleted.
