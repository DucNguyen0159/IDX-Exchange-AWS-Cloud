# Week 2 — IAM & Security Foundations

## What I set up

For week 2, I created a new IAM user called `s3-test-user` with no console access and attached my own policy, `S3UploaderOnly-henry`, to it.
I gave this user an access key and saved it in a separate CLI profile called `s3test`, so I could test as a low-privilege user instead of my `henry-admin` user.
I also created the bucket `my-training-bucket-henry` in `us-east-1`, which I will use again in week 4.
Finally, I turned on IAM Access Analyzer in `us-east-1`, and it showed 0 active findings.

## Policies

### [`S3UploaderOnly-henry.json`](policies/S3UploaderOnly-henry.json)

This is the policy attached to `s3-test-user`.
It only allows two actions, `s3:PutObject` and `s3:GetObject`, so the user can upload and download files and nothing else.
The resource is `arn:aws:s3:::my-training-bucket-henry/*`, which means every object inside my training bucket and no other bucket.
I scoped it this way because the only job of this user is to move files in and out of one bucket, so it does not need to list buckets, delete files, or change any bucket settings.
When I ran `aws s3 ls --profile s3test`, I got an `AccessDenied` error for `s3:ListAllMyBuckets`.
This is not a bug, it is least privilege working the way it should.

### [`S3UploaderWithList-henry.json`](policies/S3UploaderWithList-henry.json)

This is the other fix from Debug Lab 2.3, and I kept it for reference only, so it is not attached to any user.
It adds `s3:ListBucket` on the bucket ARN `arn:aws:s3:::my-training-bucket-henry`, while `PutObject` and `GetObject` stay on the `/*` ARN.
The two resources need to be in separate statements because `ListBucket` works on the bucket itself, but `PutObject` and `GetObject` work on the objects inside the bucket.
I would only use this version if the user also needed to see what is inside the bucket, for example with `aws s3 ls s3://my-training-bucket-henry/`.

## Debug Lab 2.3: AccessDenied on upload

In this lab, the user gets `AccessDenied` when uploading with `aws s3 cp`, even though the policy allows `s3:PutObject`.
The problem is the resource ARN.
If the policy uses `arn:aws:s3:::my-training-bucket-henry` without `/*`, it only covers the bucket, not the files inside it, so AWS finds no matching statement and denies the upload.

I tested this in the IAM Policy Simulator with `s3:PutObject` for `s3-test-user`:

| Resource tested | Result |
|---|---|
| `arn:aws:s3:::my-training-bucket-henry/file.txt` | Allowed (explicit allow in 1 statement) |
| `arn:aws:s3:::some-other-bucket/file.txt` | Denied (implicit deny, no statement matched) |
| `arn:aws:s3:::my-training-bucket-henry` | Not accepted, because `PutObject` only takes object ARNs (`bucket/key`). The CLI simulator returns `implicitDeny` |

With the correct policy, the upload worked as the low-privilege user:

```bash
aws s3 cp /tmp/file.txt s3://my-training-bucket-henry/ --profile s3test
# upload: ../../../../tmp/file.txt to s3://my-training-bucket-henry/file.txt
```

## What I learned

In IAM, everything is denied by default, and an action only works if a policy allows it on the right resource.
If there is an explicit `Deny` anywhere, it always wins over an `Allow`.
We should always test policies with the low-privilege profile, because the admin user will never see a deny.
Access Analyzer is regional, so it needs to be created in the same region as my resources (`us-east-1`).
