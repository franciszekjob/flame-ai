// 90/10 mix of /slow and /fast — produces a flame graph still dominated by
// bubble_sort but with a small Timsort sliver for contrast.

import http from 'k6/http';
import { sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://sorter.flame-ai.svc.cluster.local';
const N = __ENV.N || '5000';

export const options = {
  vus: 3,
  duration: '3m',
};

export default function () {
  if (Math.random() < 0.9) {
    http.get(`${BASE_URL}/slow?n=${N}`);
  } else {
    http.get(`${BASE_URL}/fast?n=${N}`);
  }
  sleep(0.3);
}
