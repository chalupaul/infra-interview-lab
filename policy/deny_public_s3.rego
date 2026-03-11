package terraform.s3

import future.keywords.if
import future.keywords.in

# TODO: deny any aws_s3_bucket resource with acl = "public-read" or "public-read-write"

# TODO: deny any aws_s3_bucket resource where force_destroy is not explicitly set to false

# Hint: the tfplan input structure looks like:
# input.resource_changes[_] {
#   .type       = "aws_s3_bucket"
#   .change.after.acl
#   .change.after.force_destroy
# }
