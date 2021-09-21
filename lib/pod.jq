def meld(a; b):
  if (a|type) == "object" and (b|type) == "object"
  then reduce ([a,b]|add|keys_unsorted[]) as $k ({};
    .[$k] = meld( a[$k]; b[$k]) )
  elif (a|type) == "array" and (b|type) == "array"
  then a+b
  elif b == null then a
  else b
  end;

(env | to_entries | map(select(.key | contains("BUILDKITE_")))) + (($ARGS.named.extra_env // {}) | to_entries) | map(.name= (.key | sub("/"; "_"; "g")) | del(.key)) as $env | 

(env.BUILDKITE_TIMEOUT | (tonumber * 60 + 60)) as $timeout |

(
  env.BUILDKITE_PLUGINS // "[]" |
  fromjson |
  map(to_entries) |
  flatten(1) |
  map(select(.key | contains("k8s-buildkite-plugin")) | .value) |
  first // {}
) as $config |

{
  apiVersion: "v1",
  kind: "Pod",
  metadata: {
    name: (env.BUILDKITE_PIPELINE_SLUG + "-" + env.BUILDKITE_JOB_ID),
    namespace: ($config.namespace? // "default"),
    labels: ({
      buildkite: "true",
      buildkite_commit: env.BUILDKITE_COMMIT,
      buildkite_pipeline_slug: env.BUILDKITE_PIPELINE_SLUG,
    } + ($config.labels? // {})),
  },
  spec: meld({
    containers: ([
      {
        name: "run",
        image: env.BUILDKITE_PLUGIN_K8S_IMAGE,
        command: ["sleep", ($timeout | tostring)],
        env: $env,
        resources: ($config.resources? // {}),
      }
    ]),
    restartPolicy: "Never",
    activeDeadlineSeconds: $timeout,
  }; ($config.spec? // {})),
}
