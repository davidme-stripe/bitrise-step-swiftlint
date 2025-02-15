#!/bin/bash

set -o pipefail

if [ -z "${linting_path}" ] ; then
  echo " [!] Missing required input: linting_path"

  exit 1
fi

FLAGS=''

if [ -s "${lint_config_file}" ] ; then
  FLAGS=$FLAGS' --config '"${lint_config_file}"  
fi

if [ "${strict}" = "yes" ] ; then
  echo "Running strict mode"
  FLAGS=$FLAGS' --strict'
fi

if [ "${quiet}" = "yes" ] ; then
  echo "Running quiet mode"
  FLAGS=$FLAGS' --quiet'  
fi


cd "${linting_path}"

filename="swiftlint_report"
case $reporter in
    xcode|emoji)
      filename="${filename}.txt"
      ;;
    markdown)
      filename="${filename}.md"
      ;;
    csv|html)
      filename="${filename}.${reporter}"
      ;;
    checkstyle|junit)
      filename="${filename}.xml"
      ;;
    json|sonarqube)
      filename="${filename}.json"
      ;;
esac

report_path="${BITRISE_DEPLOY_DIR}/${filename}"

case $lint_range in 
  "changed")
  echo "Linting diff only"
    files=$(git diff HEAD^ --name-only --diff-filter=d -- '*.swift')

    echo $files

    for swift_file in $(git diff HEAD^ --name-only --diff-filter=d -- '*.swift')
    do 
      swiftlint_output+=$"$(swiftlint lint --path "$swift_file" --reporter ${reporter} ${FLAGS})"
      lint_code=$?
      if [[ lint_code -ne 0 ]]; then 
        swiftlint_exit_code=${lint_code}
      fi
    done
    ;;
  
  "all") 
    echo "Linting all files"
    swiftlint_output="$(swiftlint lint --reporter ${reporter} ${FLAGS})"
    swiftlint_exit_code=$?
    ;;
esac

# This will set the `swiftlint_output` in `SWIFTLINT_REPORT` env variable. 
# so it can be used to send in Slack etc. 
envman add --key "SWIFTLINT_REPORT" --value "${swiftlint_output}"
echo "Saved swiftlint output in SWIFTLINT_REPORT"

# This will print the `swiftlint_output` into a file and set the envvariable
# so it can be used in other tasks
echo "${swiftlint_output}" > $report_path
envman add --key "SWIFTLINT_REPORT_PATH" --value "${report_path}"
echo "Saved swiftlint output in file at path SWIFTLINT_REPORT_PATH"

# Creating the sub-directory for the test run within the BITRISE_TEST_RESULT_DIR:
test_run_dir="$BITRISE_TEST_RESULT_DIR/Swiftlint"
mkdir "$test_run_dir"

# Exporting the JUnit XML test report:
cp $report_path "$test_run_dir/UnitTest.xml"

# Creating the test-info.json file with the name of the test run defined:
echo '{"test-name":"Swiftlint"}' >> "$test_run_dir/test-info.json"
echo "Done"

exit ${swiftlint_exit_code}
