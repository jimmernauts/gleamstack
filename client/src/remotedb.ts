// this imports a bare-bones version of S3 that exposes the .send operation
import { S3Client } from "@aws-sdk/client-s3"

// this imports just the getObject operation from S3
import { GetObjectCommand } from "@aws-sdk/client-s3"

// TODO:
// 1. read the DB from remote
// 2. sync changes with local DB
// 3. write it back to remote