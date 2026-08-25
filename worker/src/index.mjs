import * as glen from '../build/dev/javascript/glen/glen.mjs';
import * as mealstack_worker from '../build/dev/javascript/mealstack_worker/mealstack_worker.mjs';

export default {
  async fetch(request, env, ctx) {
    console.log(request);
    const req = glen.convert_request(request);
    const response = await mealstack_worker.handle_req(req);
    const res = glen.convert_response(response);
    return res;
  },
};
