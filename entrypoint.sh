#!/bin/sh

GF_API=${GF_API:-''}
GF_USER=${GF_USER:-admin}
GF_PASSWORD=${GF_PASSWORD:-admin}
GF_TOKEN=${GF_TOKEN:-''}

BACKEND=${BACKEND:-graphite}

CURL_AUTH="-v -u $GF_USER:$GF_PASSWORD"

if [ "x$GF_TOKEN" != "x" ] ; then
  CURL_AUTH="-v -H \"Authorization: Bearer ${GF_TOKEN}"\"
fi

print_header() {
  echo " "
  echo "------------------"
  echo $1
  echo "------------------"
}

wait_for_api() {
  echo -n "Waiting for Grafana API "

  eval curl "${CURL_AUTH} -s -f ${GF_API}/datasources"
  while [ $? -ne 0 ]; do
    echo -n "."
    sleep 2
    eval curl "${CURL_AUTH} -s -f ${GF_API}/datasources" &> /dev/null
  done
  echo " "
}

# $1 = file-path, $2 = json, $3 = api-path
import_data() {
  set -e
  echo " "
  echo $1
  echo "$2" | eval curl -s -S -H 'Content-Type:application/json' ${CURL_AUTH} --data @- ${GF_API}$3
  echo " "
  set +e
}

# $1 = filename
wrap_dashboard_json() {
  cat $1 | jq '.id = null | { dashboard:., inputs:[.__inputs[] | .value = .label | del(.label)], overwrite: true }'
}

# -----------

wait_for_api

print_header "Adding datasources"

for datasource in `ls -1 /datasources/$BACKEND/*.json`; do
  datasource_json=$( cat $datasource )
  ds_name=$( echo $datasource_json | jq -r '.name' )
  api_path="${GF_API}/datasources/id/${ds_name}"
  eval curl -f -s ${CURL_AUTH} "$api_path" &> /dev/null
  if [ $? -eq 0 ]; then
    echo "Datasource already exists: ${datasource}"
  else
    import_data "$datasource" "$datasource_json" "/datasources"
  fi
done

print_header "Adding Graphite dashboards"

for dashboard in `ls -1 /dashboards/$BACKEND/*.json`; do
  dashboard_json=$( wrap_dashboard_json $dashboard )
  import_data "$dashboard" "$dashboard_json" "/dashboards/import"
done

print_header "Done!"
