// Floods the /slow endpoint to make bubble_sort dominate the flame graph.
//
// Local:    BASE_URL=http://localhost:8080 k6 run k6/scenarios/slow-flood.js
// Cluster:  applied via k6-operator (see k6/k8s/testrun.yaml).

import http from 'k6/http';
import { sleep } from 'k6';

//const BASE_URL = __ENV.BASE_URL || 'http://sorter.flame-ai.svc.cluster.local';
const BASE_URL="http://localhost:8080";
const N = __ENV.N || '5000';

export const options = {
  scenarios: {
    slow_flood: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: '30s', target: 4 },
        { duration: '2m', target: 4 },
        { duration: '30s', target: 0 },
      ],
      gracefulRampDown: '10s',
    },
  },
};

export default function () {
  http.get(`${BASE_URL}/slow?n=${N}`);
  sleep(0.5);
}
