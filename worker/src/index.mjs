import * as glen from '../glen/glen.mjs';
import * as mealstack_worker from './mealstack_worker.mjs';

export default {
  async fetch(request, _env, _ctx) {
    console.log(request);
    const req = glen.convert_request(request);
    const response = await mealstack_worker.handle_req(req);
    const res = glen.convert_response(response);

    return res;
  },
};