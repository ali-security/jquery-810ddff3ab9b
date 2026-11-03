#!/bin/sh
# Seal fork-CI helper (Travis after_script): keep the job open until Travis has
# archived this job's own log up to the test results, so a log harvested the
# moment the build finishes is complete. Travis archives log parts
# asynchronously, often minutes behind the job.
#
# Usage: sh test/seal-wait-for-log.sh <grunt|qunit>
# after_script cannot change the build result; this only delays job end.
# Lives under test/ so .npmignore's /test keeps it out of the tarball.

mode="$1"
case "$mode" in
	grunt) pattern='(Done, without errors|Aborted due to warnings)' ;;
	qunit) pattern='Tests: [0-9]+ passed, [0-9]+ failed' ;;
	*) echo "seal-wait-for-log: unknown mode '$mode'"; exit 0 ;;
esac

if [ -z "$TRAVIS_JOB_ID" ]; then
	echo "seal-wait-for-log: TRAVIS_JOB_ID unset, nothing to wait for"
	exit 0
fi

url="https://api.travis-ci.com/v3/job/${TRAVIS_JOB_ID}/log.txt"
i=0
# Cap at 15 min: an archive stalled longer than that does not catch up in-job.
while [ "$i" -lt 45 ]; do
	if curl -sfL "$url" 2>/dev/null | grep -Eq "$pattern"; then
		echo "seal-wait-for-log: results archived after $((i * 20))s"
		# Let the lines printed after the summary land too.
		sleep 20
		exit 0
	fi
	i=$((i + 1))
	# Print on every poll: Travis errors a job after 10 min without output,
	# and fresh output also prompts it to archive the pending log parts.
	echo "seal-wait-for-log: results not archived yet ($((i * 20))s)"
	sleep 20
done
echo "seal-wait-for-log: gave up after $((i * 20))s"
exit 0
