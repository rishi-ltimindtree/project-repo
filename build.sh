
#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(pwd)"
SRC_JAVA="${PROJECT_ROOT}/src/main/java"
WEBAPP_DIR="${PROJECT_ROOT}/src/main/webapp"
WEBINF_DIR="${WEBAPP_DIR}/WEB-INF"
ALT_WEBINF_DIR="${PROJECT_ROOT}/src/WEB-INF"   # legacy fallback if used
CLASSES_DIR="${WEBINF_DIR}/classes"

echo "=> Project root: ${PROJECT_ROOT}"

# Ensure class output directory exists
mkdir -p "${CLASSES_DIR}"

# Build classpath: include WEB-INF/lib jars if present
CLASSPATH="${CLASSES_DIR}"
LIB_DIR=""
if [ -d "${WEBINF_DIR}/lib" ]; then
  LIB_DIR="${WEBINF_DIR}/lib"
elif [ -d "${ALT_WEBINF_DIR}/lib" ]; then
  # fallback to src/WEB-INF/lib if used
  LIB_DIR="${ALT_WEBINF_DIR}/lib"
fi

if [ -n "${LIB_DIR}" ]; then
  CLASSPATH="${LIB_DIR}/*:${CLASSES_DIR}"
fi
echo "=> Using CLASSPATH: ${CLASSPATH}"

echo "=> Compiling Java sources from: ${SRC_JAVA}"
JAVA_SOURCES=$(find "${SRC_JAVA}" -type f -name "*.java" || true)
if [ -z "${JAVA_SOURCES}" ]; then
  echo "ERROR: No Java source files found under ${SRC_JAVA}"
  exit 1
fi

javac -classpath "${CLASSPATH}" -d "${CLASSES_DIR}" ${JAVA_SOURCES}
echo "   Compilation complete. Classes in: ${CLASSES_DIR}"

# Prepare WAR staging (use the webapp as the content root)
WAR_NAME="ROOT.war"
WAR_PATH="${PROJECT_ROOT}/${WAR_NAME}"
TMP_STAGING="${PROJECT_ROOT}/_war_staging"
rm -rf "${TMP_STAGING}"
mkdir -p "${TMP_STAGING}"

echo "=> Staging webapp content from: ${WEBAPP_DIR}"
rsync -a "${WEBAPP_DIR}/" "${TMP_STAGING}/"

# If you keep .ebextensions, include them at the WAR root (Elastic Beanstalk)
if [ -d "${PROJECT_ROOT}/.ebextensions" ]; then
  echo "=> Including .ebextensions"
  rsync -a "${PROJECT_ROOT}/.ebextensions/" "${TMP_STAGING}/.ebextensions/"
fi

# Create WAR
echo "=> Creating ${WAR_NAME}"
(
  cd "${TMP_STAGING}"
  jar -cf "${WAR_PATH}" .
)

echo "=> ${WAR_NAME} created at: ${WAR_PATH}"

# Optional: copy to local Tomcat (macOS default path)
if [ -d "/Library/Tomcat/webapps" ]; then
  cp "${WAR_PATH}" /Library/Tomcat/webapps/
  echo "=> Copied WAR to /Library/Tomcat/webapps"
fi

echo "SUCCESS"
