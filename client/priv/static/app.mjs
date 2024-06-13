// build/dev/javascript/prelude.mjs
var CustomType = class {
  withFields(fields) {
    let properties = Object.keys(this).map(
      (label2) => label2 in fields ? fields[label2] : this[label2]
    );
    return new this.constructor(...properties);
  }
};
var List = class {
  static fromArray(array3, tail) {
    let t = tail || new Empty();
    for (let i = array3.length - 1; i >= 0; --i) {
      t = new NonEmpty(array3[i], t);
    }
    return t;
  }
  [Symbol.iterator]() {
    return new ListIterator(this);
  }
  toArray() {
    return [...this];
  }
  // @internal
  atLeastLength(desired) {
    for (let _ of this) {
      if (desired <= 0)
        return true;
      desired--;
    }
    return desired <= 0;
  }
  // @internal
  hasLength(desired) {
    for (let _ of this) {
      if (desired <= 0)
        return false;
      desired--;
    }
    return desired === 0;
  }
  countLength() {
    let length6 = 0;
    for (let _ of this)
      length6++;
    return length6;
  }
};
function prepend(element2, tail) {
  return new NonEmpty(element2, tail);
}
function toList(elements, tail) {
  return List.fromArray(elements, tail);
}
var ListIterator = class {
  #current;
  constructor(current) {
    this.#current = current;
  }
  next() {
    if (this.#current instanceof Empty) {
      return { done: true };
    } else {
      let { head, tail } = this.#current;
      this.#current = tail;
      return { value: head, done: false };
    }
  }
};
var Empty = class extends List {
};
var NonEmpty = class extends List {
  constructor(head, tail) {
    super();
    this.head = head;
    this.tail = tail;
  }
};
var BitArray = class _BitArray {
  constructor(buffer) {
    if (!(buffer instanceof Uint8Array)) {
      throw "BitArray can only be constructed from a Uint8Array";
    }
    this.buffer = buffer;
  }
  // @internal
  get length() {
    return this.buffer.length;
  }
  // @internal
  byteAt(index3) {
    return this.buffer[index3];
  }
  // @internal
  floatAt(index3) {
    return byteArrayToFloat(this.buffer.slice(index3, index3 + 8));
  }
  // @internal
  intFromSlice(start4, end) {
    return byteArrayToInt(this.buffer.slice(start4, end));
  }
  // @internal
  binaryFromSlice(start4, end) {
    return new _BitArray(this.buffer.slice(start4, end));
  }
  // @internal
  sliceAfter(index3) {
    return new _BitArray(this.buffer.slice(index3));
  }
};
var UtfCodepoint = class {
  constructor(value4) {
    this.value = value4;
  }
};
function byteArrayToInt(byteArray) {
  byteArray = byteArray.reverse();
  let value4 = 0;
  for (let i = byteArray.length - 1; i >= 0; i--) {
    value4 = value4 * 256 + byteArray[i];
  }
  return value4;
}
function byteArrayToFloat(byteArray) {
  return new Float64Array(byteArray.reverse().buffer)[0];
}
var Result = class _Result extends CustomType {
  // @internal
  static isResult(data) {
    return data instanceof _Result;
  }
};
var Ok2 = class extends Result {
  constructor(value4) {
    super();
    this[0] = value4;
  }
  // @internal
  isOk() {
    return true;
  }
};
var Error2 = class extends Result {
  constructor(detail) {
    super();
    this[0] = detail;
  }
  // @internal
  isOk() {
    return false;
  }
};
function isEqual(x, y) {
  let values2 = [x, y];
  while (values2.length) {
    let a2 = values2.pop();
    let b = values2.pop();
    if (a2 === b)
      continue;
    if (!isObject(a2) || !isObject(b))
      return false;
    let unequal = !structurallyCompatibleObjects(a2, b) || unequalDates(a2, b) || unequalBuffers(a2, b) || unequalArrays(a2, b) || unequalMaps(a2, b) || unequalSets(a2, b) || unequalRegExps(a2, b);
    if (unequal)
      return false;
    const proto = Object.getPrototypeOf(a2);
    if (proto !== null && typeof proto.equals === "function") {
      try {
        if (a2.equals(b))
          continue;
        else
          return false;
      } catch {
      }
    }
    let [keys2, get3] = getters(a2);
    for (let k of keys2(a2)) {
      values2.push(get3(a2, k), get3(b, k));
    }
  }
  return true;
}
function getters(object3) {
  if (object3 instanceof Map) {
    return [(x) => x.keys(), (x, y) => x.get(y)];
  } else {
    let extra = object3 instanceof globalThis.Error ? ["message"] : [];
    return [(x) => [...extra, ...Object.keys(x)], (x, y) => x[y]];
  }
}
function unequalDates(a2, b) {
  return a2 instanceof Date && (a2 > b || a2 < b);
}
function unequalBuffers(a2, b) {
  return a2.buffer instanceof ArrayBuffer && a2.BYTES_PER_ELEMENT && !(a2.byteLength === b.byteLength && a2.every((n, i) => n === b[i]));
}
function unequalArrays(a2, b) {
  return Array.isArray(a2) && a2.length !== b.length;
}
function unequalMaps(a2, b) {
  return a2 instanceof Map && a2.size !== b.size;
}
function unequalSets(a2, b) {
  return a2 instanceof Set && (a2.size != b.size || [...a2].some((e) => !b.has(e)));
}
function unequalRegExps(a2, b) {
  return a2 instanceof RegExp && (a2.source !== b.source || a2.flags !== b.flags);
}
function isObject(a2) {
  return typeof a2 === "object" && a2 !== null;
}
function structurallyCompatibleObjects(a2, b) {
  if (typeof a2 !== "object" && typeof b !== "object" && (!a2 || !b))
    return false;
  let nonstructural = [Promise, WeakSet, WeakMap, Function];
  if (nonstructural.some((c) => a2 instanceof c))
    return false;
  return a2.constructor === b.constructor;
}
function remainderInt(a2, b) {
  if (b === 0) {
    return 0;
  } else {
    return a2 % b;
  }
}
function divideInt(a2, b) {
  return Math.trunc(divideFloat(a2, b));
}
function divideFloat(a2, b) {
  if (b === 0) {
    return 0;
  } else {
    return a2 / b;
  }
}
function makeError(variant, module, line, fn, message, extra) {
  let error = new globalThis.Error(message);
  error.gleam_error = variant;
  error.module = module;
  error.line = line;
  error.fn = fn;
  for (let k in extra)
    error[k] = extra[k];
  return error;
}

// build/dev/javascript/gleam_stdlib/gleam/option.mjs
var Some = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var None = class extends CustomType {
};
function to_result(option2, e) {
  if (option2 instanceof Some) {
    let a2 = option2[0];
    return new Ok2(a2);
  } else {
    return new Error2(e);
  }
}
function from_result(result) {
  if (result.isOk()) {
    let a2 = result[0];
    return new Some(a2);
  } else {
    return new None();
  }
}
function unwrap(option2, default$) {
  if (option2 instanceof Some) {
    let x = option2[0];
    return x;
  } else {
    return default$;
  }
}
function map(option2, fun) {
  if (option2 instanceof Some) {
    let x = option2[0];
    return new Some(fun(x));
  } else {
    return new None();
  }
}
function or(first3, second2) {
  if (first3 instanceof Some) {
    return first3;
  } else {
    return second2;
  }
}

// build/dev/javascript/gleam_stdlib/gleam/float.mjs
function to_string(x) {
  return float_to_string(x);
}

// build/dev/javascript/gleam_stdlib/gleam/int.mjs
function parse(string3) {
  return parse_int(string3);
}
function to_string3(x) {
  return to_string2(x);
}
function to_float(x) {
  return identity(x);
}
function floor_divide(dividend, divisor) {
  if (divisor === 0) {
    return new Error2(void 0);
  } else {
    let divisor$1 = divisor;
    let $ = dividend * divisor$1 < 0 && remainderInt(dividend, divisor$1) !== 0;
    if ($) {
      return new Ok2(divideInt(dividend, divisor$1) - 1);
    } else {
      return new Ok2(divideInt(dividend, divisor$1));
    }
  }
}

// build/dev/javascript/gleam_stdlib/gleam/result.mjs
function map2(result, fun) {
  if (result.isOk()) {
    let x = result[0];
    return new Ok2(fun(x));
  } else {
    let e = result[0];
    return new Error2(e);
  }
}
function map_error(result, fun) {
  if (result.isOk()) {
    let x = result[0];
    return new Ok2(x);
  } else {
    let error = result[0];
    return new Error2(fun(error));
  }
}
function flatten(result) {
  if (result.isOk()) {
    let x = result[0];
    return x;
  } else {
    let error = result[0];
    return new Error2(error);
  }
}
function try$(result, fun) {
  if (result.isOk()) {
    let x = result[0];
    return fun(x);
  } else {
    let e = result[0];
    return new Error2(e);
  }
}
function unwrap2(result, default$) {
  if (result.isOk()) {
    let v = result[0];
    return v;
  } else {
    return default$;
  }
}
function all(results) {
  return try_map(results, (x) => {
    return x;
  });
}

// build/dev/javascript/gleam_stdlib/gleam/string_builder.mjs
function append_builder(builder, suffix) {
  return add(builder, suffix);
}
function from_strings(strings) {
  return concat(strings);
}
function from_string(string3) {
  return identity(string3);
}
function append(builder, second2) {
  return append_builder(builder, from_string(second2));
}
function to_string4(builder) {
  return identity(builder);
}
function split2(iodata, pattern) {
  return split(iodata, pattern);
}

// build/dev/javascript/gleam_stdlib/gleam/dynamic.mjs
var DecodeError = class extends CustomType {
  constructor(expected, found, path) {
    super();
    this.expected = expected;
    this.found = found;
    this.path = path;
  }
};
function from(a2) {
  return identity(a2);
}
function unsafe_coerce(a2) {
  return identity(a2);
}
function string(data) {
  return decode_string(data);
}
function classify(data) {
  return classify_dynamic(data);
}
function int(data) {
  return decode_int(data);
}
function shallow_list(value4) {
  return decode_list(value4);
}
function any(decoders) {
  return (data) => {
    if (decoders.hasLength(0)) {
      return new Error2(
        toList([new DecodeError("another type", classify(data), toList([]))])
      );
    } else {
      let decoder = decoders.head;
      let decoders$1 = decoders.tail;
      let $ = decoder(data);
      if ($.isOk()) {
        let decoded = $[0];
        return new Ok2(decoded);
      } else {
        return any(decoders$1)(data);
      }
    }
  };
}
function all_errors(result) {
  if (result.isOk()) {
    return toList([]);
  } else {
    let errors = result[0];
    return errors;
  }
}
function decode1(constructor, t1) {
  return (value4) => {
    let $ = t1(value4);
    if ($.isOk()) {
      let a2 = $[0];
      return new Ok2(constructor(a2));
    } else {
      let a2 = $;
      return new Error2(all_errors(a2));
    }
  };
}
function push_path(error, name2) {
  let name$1 = from(name2);
  let decoder = any(
    toList([string, (x) => {
      return map2(int(x), to_string3);
    }])
  );
  let name$2 = (() => {
    let $ = decoder(name$1);
    if ($.isOk()) {
      let name$22 = $[0];
      return name$22;
    } else {
      let _pipe = toList(["<", classify(name$1), ">"]);
      let _pipe$1 = from_strings(_pipe);
      return to_string4(_pipe$1);
    }
  })();
  return error.withFields({ path: prepend(name$2, error.path) });
}
function list(decoder_type) {
  return (dynamic2) => {
    return try$(
      shallow_list(dynamic2),
      (list2) => {
        let _pipe = list2;
        let _pipe$1 = try_map(_pipe, decoder_type);
        return map_errors(
          _pipe$1,
          (_capture) => {
            return push_path(_capture, "*");
          }
        );
      }
    );
  };
}
function map_errors(result, f) {
  return map_error(
    result,
    (_capture) => {
      return map3(_capture, f);
    }
  );
}
function field(name2, inner_type) {
  return (value4) => {
    let missing_field_error = new DecodeError("field", "nothing", toList([]));
    return try$(
      decode_field(value4, name2),
      (maybe_inner) => {
        let _pipe = maybe_inner;
        let _pipe$1 = to_result(_pipe, toList([missing_field_error]));
        let _pipe$2 = try$(_pipe$1, inner_type);
        return map_errors(
          _pipe$2,
          (_capture) => {
            return push_path(_capture, name2);
          }
        );
      }
    );
  };
}
function optional_field(name2, inner_type) {
  return (value4) => {
    return try$(
      decode_field(value4, name2),
      (maybe_inner) => {
        if (maybe_inner instanceof None) {
          return new Ok2(new None());
        } else {
          let dynamic_inner = maybe_inner[0];
          let _pipe = dynamic_inner;
          let _pipe$1 = decode_option(_pipe, inner_type);
          return map_errors(
            _pipe$1,
            (_capture) => {
              return push_path(_capture, name2);
            }
          );
        }
      }
    );
  };
}
function dict(key_type, value_type) {
  return (value4) => {
    return try$(
      decode_map(value4),
      (map8) => {
        return try$(
          (() => {
            let _pipe = map8;
            let _pipe$1 = map_to_list(_pipe);
            return try_map(
              _pipe$1,
              (pair) => {
                let k = pair[0];
                let v = pair[1];
                return try$(
                  (() => {
                    let _pipe$2 = key_type(k);
                    return map_errors(
                      _pipe$2,
                      (_capture) => {
                        return push_path(_capture, "keys");
                      }
                    );
                  })(),
                  (k2) => {
                    return try$(
                      (() => {
                        let _pipe$2 = value_type(v);
                        return map_errors(
                          _pipe$2,
                          (_capture) => {
                            return push_path(_capture, "values");
                          }
                        );
                      })(),
                      (v2) => {
                        return new Ok2([k2, v2]);
                      }
                    );
                  }
                );
              }
            );
          })(),
          (pairs) => {
            return new Ok2(from_list(pairs));
          }
        );
      }
    );
  };
}
function decode2(constructor, t1, t2) {
  return (value4) => {
    let $ = t1(value4);
    let $1 = t2(value4);
    if ($.isOk() && $1.isOk()) {
      let a2 = $[0];
      let b = $1[0];
      return new Ok2(constructor(a2, b));
    } else {
      let a2 = $;
      let b = $1;
      return new Error2(concat2(toList([all_errors(a2), all_errors(b)])));
    }
  };
}
function decode4(constructor, t1, t2, t3, t4) {
  return (x) => {
    let $ = t1(x);
    let $1 = t2(x);
    let $2 = t3(x);
    let $3 = t4(x);
    if ($.isOk() && $1.isOk() && $2.isOk() && $3.isOk()) {
      let a2 = $[0];
      let b = $1[0];
      let c = $2[0];
      let d = $3[0];
      return new Ok2(constructor(a2, b, c, d));
    } else {
      let a2 = $;
      let b = $1;
      let c = $2;
      let d = $3;
      return new Error2(
        concat2(
          toList([all_errors(a2), all_errors(b), all_errors(c), all_errors(d)])
        )
      );
    }
  };
}
function decode9(constructor, t1, t2, t3, t4, t5, t6, t7, t8, t9) {
  return (x) => {
    let $ = t1(x);
    let $1 = t2(x);
    let $2 = t3(x);
    let $3 = t4(x);
    let $4 = t5(x);
    let $5 = t6(x);
    let $6 = t7(x);
    let $7 = t8(x);
    let $8 = t9(x);
    if ($.isOk() && $1.isOk() && $2.isOk() && $3.isOk() && $4.isOk() && $5.isOk() && $6.isOk() && $7.isOk() && $8.isOk()) {
      let a2 = $[0];
      let b = $1[0];
      let c = $2[0];
      let d = $3[0];
      let e = $4[0];
      let f = $5[0];
      let g = $6[0];
      let h = $7[0];
      let i = $8[0];
      return new Ok2(constructor(a2, b, c, d, e, f, g, h, i));
    } else {
      let a2 = $;
      let b = $1;
      let c = $2;
      let d = $3;
      let e = $4;
      let f = $5;
      let g = $6;
      let h = $7;
      let i = $8;
      return new Error2(
        concat2(
          toList([
            all_errors(a2),
            all_errors(b),
            all_errors(c),
            all_errors(d),
            all_errors(e),
            all_errors(f),
            all_errors(g),
            all_errors(h),
            all_errors(i)
          ])
        )
      );
    }
  };
}

// build/dev/javascript/gleam_stdlib/dict.mjs
var referenceMap = /* @__PURE__ */ new WeakMap();
var tempDataView = new DataView(new ArrayBuffer(8));
var referenceUID = 0;
function hashByReference(o) {
  const known = referenceMap.get(o);
  if (known !== void 0) {
    return known;
  }
  const hash = referenceUID++;
  if (referenceUID === 2147483647) {
    referenceUID = 0;
  }
  referenceMap.set(o, hash);
  return hash;
}
function hashMerge(a2, b) {
  return a2 ^ b + 2654435769 + (a2 << 6) + (a2 >> 2) | 0;
}
function hashString(s) {
  let hash = 0;
  const len = s.length;
  for (let i = 0; i < len; i++) {
    hash = Math.imul(31, hash) + s.charCodeAt(i) | 0;
  }
  return hash;
}
function hashNumber(n) {
  tempDataView.setFloat64(0, n);
  const i = tempDataView.getInt32(0);
  const j = tempDataView.getInt32(4);
  return Math.imul(73244475, i >> 16 ^ i) ^ j;
}
function hashBigInt(n) {
  return hashString(n.toString());
}
function hashObject(o) {
  const proto = Object.getPrototypeOf(o);
  if (proto !== null && typeof proto.hashCode === "function") {
    try {
      const code = o.hashCode(o);
      if (typeof code === "number") {
        return code;
      }
    } catch {
    }
  }
  if (o instanceof Promise || o instanceof WeakSet || o instanceof WeakMap) {
    return hashByReference(o);
  }
  if (o instanceof Date) {
    return hashNumber(o.getTime());
  }
  let h = 0;
  if (o instanceof ArrayBuffer) {
    o = new Uint8Array(o);
  }
  if (Array.isArray(o) || o instanceof Uint8Array) {
    for (let i = 0; i < o.length; i++) {
      h = Math.imul(31, h) + getHash(o[i]) | 0;
    }
  } else if (o instanceof Set) {
    o.forEach((v) => {
      h = h + getHash(v) | 0;
    });
  } else if (o instanceof Map) {
    o.forEach((v, k) => {
      h = h + hashMerge(getHash(v), getHash(k)) | 0;
    });
  } else {
    const keys2 = Object.keys(o);
    for (let i = 0; i < keys2.length; i++) {
      const k = keys2[i];
      const v = o[k];
      h = h + hashMerge(getHash(v), hashString(k)) | 0;
    }
  }
  return h;
}
function getHash(u) {
  if (u === null)
    return 1108378658;
  if (u === void 0)
    return 1108378659;
  if (u === true)
    return 1108378657;
  if (u === false)
    return 1108378656;
  switch (typeof u) {
    case "number":
      return hashNumber(u);
    case "string":
      return hashString(u);
    case "bigint":
      return hashBigInt(u);
    case "object":
      return hashObject(u);
    case "symbol":
      return hashByReference(u);
    case "function":
      return hashByReference(u);
    default:
      return 0;
  }
}
var SHIFT = 5;
var BUCKET_SIZE = Math.pow(2, SHIFT);
var MASK = BUCKET_SIZE - 1;
var MAX_INDEX_NODE = BUCKET_SIZE / 2;
var MIN_ARRAY_NODE = BUCKET_SIZE / 4;
var ENTRY = 0;
var ARRAY_NODE = 1;
var INDEX_NODE = 2;
var COLLISION_NODE = 3;
var EMPTY = {
  type: INDEX_NODE,
  bitmap: 0,
  array: []
};
function mask(hash, shift) {
  return hash >>> shift & MASK;
}
function bitpos(hash, shift) {
  return 1 << mask(hash, shift);
}
function bitcount(x) {
  x -= x >> 1 & 1431655765;
  x = (x & 858993459) + (x >> 2 & 858993459);
  x = x + (x >> 4) & 252645135;
  x += x >> 8;
  x += x >> 16;
  return x & 127;
}
function index(bitmap, bit) {
  return bitcount(bitmap & bit - 1);
}
function cloneAndSet(arr, at, val) {
  const len = arr.length;
  const out = new Array(len);
  for (let i = 0; i < len; ++i) {
    out[i] = arr[i];
  }
  out[at] = val;
  return out;
}
function spliceIn(arr, at, val) {
  const len = arr.length;
  const out = new Array(len + 1);
  let i = 0;
  let g = 0;
  while (i < at) {
    out[g++] = arr[i++];
  }
  out[g++] = val;
  while (i < len) {
    out[g++] = arr[i++];
  }
  return out;
}
function spliceOut(arr, at) {
  const len = arr.length;
  const out = new Array(len - 1);
  let i = 0;
  let g = 0;
  while (i < at) {
    out[g++] = arr[i++];
  }
  ++i;
  while (i < len) {
    out[g++] = arr[i++];
  }
  return out;
}
function createNode(shift, key1, val1, key2hash, key2, val2) {
  const key1hash = getHash(key1);
  if (key1hash === key2hash) {
    return {
      type: COLLISION_NODE,
      hash: key1hash,
      array: [
        { type: ENTRY, k: key1, v: val1 },
        { type: ENTRY, k: key2, v: val2 }
      ]
    };
  }
  const addedLeaf = { val: false };
  return assoc(
    assocIndex(EMPTY, shift, key1hash, key1, val1, addedLeaf),
    shift,
    key2hash,
    key2,
    val2,
    addedLeaf
  );
}
function assoc(root2, shift, hash, key2, val, addedLeaf) {
  switch (root2.type) {
    case ARRAY_NODE:
      return assocArray(root2, shift, hash, key2, val, addedLeaf);
    case INDEX_NODE:
      return assocIndex(root2, shift, hash, key2, val, addedLeaf);
    case COLLISION_NODE:
      return assocCollision(root2, shift, hash, key2, val, addedLeaf);
  }
}
function assocArray(root2, shift, hash, key2, val, addedLeaf) {
  const idx = mask(hash, shift);
  const node = root2.array[idx];
  if (node === void 0) {
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root2.size + 1,
      array: cloneAndSet(root2.array, idx, { type: ENTRY, k: key2, v: val })
    };
  }
  if (node.type === ENTRY) {
    if (isEqual(key2, node.k)) {
      if (val === node.v) {
        return root2;
      }
      return {
        type: ARRAY_NODE,
        size: root2.size,
        array: cloneAndSet(root2.array, idx, {
          type: ENTRY,
          k: key2,
          v: val
        })
      };
    }
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root2.size,
      array: cloneAndSet(
        root2.array,
        idx,
        createNode(shift + SHIFT, node.k, node.v, hash, key2, val)
      )
    };
  }
  const n = assoc(node, shift + SHIFT, hash, key2, val, addedLeaf);
  if (n === node) {
    return root2;
  }
  return {
    type: ARRAY_NODE,
    size: root2.size,
    array: cloneAndSet(root2.array, idx, n)
  };
}
function assocIndex(root2, shift, hash, key2, val, addedLeaf) {
  const bit = bitpos(hash, shift);
  const idx = index(root2.bitmap, bit);
  if ((root2.bitmap & bit) !== 0) {
    const node = root2.array[idx];
    if (node.type !== ENTRY) {
      const n = assoc(node, shift + SHIFT, hash, key2, val, addedLeaf);
      if (n === node) {
        return root2;
      }
      return {
        type: INDEX_NODE,
        bitmap: root2.bitmap,
        array: cloneAndSet(root2.array, idx, n)
      };
    }
    const nodeKey = node.k;
    if (isEqual(key2, nodeKey)) {
      if (val === node.v) {
        return root2;
      }
      return {
        type: INDEX_NODE,
        bitmap: root2.bitmap,
        array: cloneAndSet(root2.array, idx, {
          type: ENTRY,
          k: key2,
          v: val
        })
      };
    }
    addedLeaf.val = true;
    return {
      type: INDEX_NODE,
      bitmap: root2.bitmap,
      array: cloneAndSet(
        root2.array,
        idx,
        createNode(shift + SHIFT, nodeKey, node.v, hash, key2, val)
      )
    };
  } else {
    const n = root2.array.length;
    if (n >= MAX_INDEX_NODE) {
      const nodes = new Array(32);
      const jdx = mask(hash, shift);
      nodes[jdx] = assocIndex(EMPTY, shift + SHIFT, hash, key2, val, addedLeaf);
      let j = 0;
      let bitmap = root2.bitmap;
      for (let i = 0; i < 32; i++) {
        if ((bitmap & 1) !== 0) {
          const node = root2.array[j++];
          nodes[i] = node;
        }
        bitmap = bitmap >>> 1;
      }
      return {
        type: ARRAY_NODE,
        size: n + 1,
        array: nodes
      };
    } else {
      const newArray = spliceIn(root2.array, idx, {
        type: ENTRY,
        k: key2,
        v: val
      });
      addedLeaf.val = true;
      return {
        type: INDEX_NODE,
        bitmap: root2.bitmap | bit,
        array: newArray
      };
    }
  }
}
function assocCollision(root2, shift, hash, key2, val, addedLeaf) {
  if (hash === root2.hash) {
    const idx = collisionIndexOf(root2, key2);
    if (idx !== -1) {
      const entry = root2.array[idx];
      if (entry.v === val) {
        return root2;
      }
      return {
        type: COLLISION_NODE,
        hash,
        array: cloneAndSet(root2.array, idx, { type: ENTRY, k: key2, v: val })
      };
    }
    const size = root2.array.length;
    addedLeaf.val = true;
    return {
      type: COLLISION_NODE,
      hash,
      array: cloneAndSet(root2.array, size, { type: ENTRY, k: key2, v: val })
    };
  }
  return assoc(
    {
      type: INDEX_NODE,
      bitmap: bitpos(root2.hash, shift),
      array: [root2]
    },
    shift,
    hash,
    key2,
    val,
    addedLeaf
  );
}
function collisionIndexOf(root2, key2) {
  const size = root2.array.length;
  for (let i = 0; i < size; i++) {
    if (isEqual(key2, root2.array[i].k)) {
      return i;
    }
  }
  return -1;
}
function find(root2, shift, hash, key2) {
  switch (root2.type) {
    case ARRAY_NODE:
      return findArray(root2, shift, hash, key2);
    case INDEX_NODE:
      return findIndex(root2, shift, hash, key2);
    case COLLISION_NODE:
      return findCollision(root2, key2);
  }
}
function findArray(root2, shift, hash, key2) {
  const idx = mask(hash, shift);
  const node = root2.array[idx];
  if (node === void 0) {
    return void 0;
  }
  if (node.type !== ENTRY) {
    return find(node, shift + SHIFT, hash, key2);
  }
  if (isEqual(key2, node.k)) {
    return node;
  }
  return void 0;
}
function findIndex(root2, shift, hash, key2) {
  const bit = bitpos(hash, shift);
  if ((root2.bitmap & bit) === 0) {
    return void 0;
  }
  const idx = index(root2.bitmap, bit);
  const node = root2.array[idx];
  if (node.type !== ENTRY) {
    return find(node, shift + SHIFT, hash, key2);
  }
  if (isEqual(key2, node.k)) {
    return node;
  }
  return void 0;
}
function findCollision(root2, key2) {
  const idx = collisionIndexOf(root2, key2);
  if (idx < 0) {
    return void 0;
  }
  return root2.array[idx];
}
function without(root2, shift, hash, key2) {
  switch (root2.type) {
    case ARRAY_NODE:
      return withoutArray(root2, shift, hash, key2);
    case INDEX_NODE:
      return withoutIndex(root2, shift, hash, key2);
    case COLLISION_NODE:
      return withoutCollision(root2, key2);
  }
}
function withoutArray(root2, shift, hash, key2) {
  const idx = mask(hash, shift);
  const node = root2.array[idx];
  if (node === void 0) {
    return root2;
  }
  let n = void 0;
  if (node.type === ENTRY) {
    if (!isEqual(node.k, key2)) {
      return root2;
    }
  } else {
    n = without(node, shift + SHIFT, hash, key2);
    if (n === node) {
      return root2;
    }
  }
  if (n === void 0) {
    if (root2.size <= MIN_ARRAY_NODE) {
      const arr = root2.array;
      const out = new Array(root2.size - 1);
      let i = 0;
      let j = 0;
      let bitmap = 0;
      while (i < idx) {
        const nv = arr[i];
        if (nv !== void 0) {
          out[j] = nv;
          bitmap |= 1 << i;
          ++j;
        }
        ++i;
      }
      ++i;
      while (i < arr.length) {
        const nv = arr[i];
        if (nv !== void 0) {
          out[j] = nv;
          bitmap |= 1 << i;
          ++j;
        }
        ++i;
      }
      return {
        type: INDEX_NODE,
        bitmap,
        array: out
      };
    }
    return {
      type: ARRAY_NODE,
      size: root2.size - 1,
      array: cloneAndSet(root2.array, idx, n)
    };
  }
  return {
    type: ARRAY_NODE,
    size: root2.size,
    array: cloneAndSet(root2.array, idx, n)
  };
}
function withoutIndex(root2, shift, hash, key2) {
  const bit = bitpos(hash, shift);
  if ((root2.bitmap & bit) === 0) {
    return root2;
  }
  const idx = index(root2.bitmap, bit);
  const node = root2.array[idx];
  if (node.type !== ENTRY) {
    const n = without(node, shift + SHIFT, hash, key2);
    if (n === node) {
      return root2;
    }
    if (n !== void 0) {
      return {
        type: INDEX_NODE,
        bitmap: root2.bitmap,
        array: cloneAndSet(root2.array, idx, n)
      };
    }
    if (root2.bitmap === bit) {
      return void 0;
    }
    return {
      type: INDEX_NODE,
      bitmap: root2.bitmap ^ bit,
      array: spliceOut(root2.array, idx)
    };
  }
  if (isEqual(key2, node.k)) {
    if (root2.bitmap === bit) {
      return void 0;
    }
    return {
      type: INDEX_NODE,
      bitmap: root2.bitmap ^ bit,
      array: spliceOut(root2.array, idx)
    };
  }
  return root2;
}
function withoutCollision(root2, key2) {
  const idx = collisionIndexOf(root2, key2);
  if (idx < 0) {
    return root2;
  }
  if (root2.array.length === 1) {
    return void 0;
  }
  return {
    type: COLLISION_NODE,
    hash: root2.hash,
    array: spliceOut(root2.array, idx)
  };
}
function forEach(root2, fn) {
  if (root2 === void 0) {
    return;
  }
  const items = root2.array;
  const size = items.length;
  for (let i = 0; i < size; i++) {
    const item = items[i];
    if (item === void 0) {
      continue;
    }
    if (item.type === ENTRY) {
      fn(item.v, item.k);
      continue;
    }
    forEach(item, fn);
  }
}
var Dict = class _Dict {
  /**
   * @template V
   * @param {Record<string,V>} o
   * @returns {Dict<string,V>}
   */
  static fromObject(o) {
    const keys2 = Object.keys(o);
    let m = _Dict.new();
    for (let i = 0; i < keys2.length; i++) {
      const k = keys2[i];
      m = m.set(k, o[k]);
    }
    return m;
  }
  /**
   * @template K,V
   * @param {Map<K,V>} o
   * @returns {Dict<K,V>}
   */
  static fromMap(o) {
    let m = _Dict.new();
    o.forEach((v, k) => {
      m = m.set(k, v);
    });
    return m;
  }
  static new() {
    return new _Dict(void 0, 0);
  }
  /**
   * @param {undefined | Node<K,V>} root
   * @param {number} size
   */
  constructor(root2, size) {
    this.root = root2;
    this.size = size;
  }
  /**
   * @template NotFound
   * @param {K} key
   * @param {NotFound} notFound
   * @returns {NotFound | V}
   */
  get(key2, notFound) {
    if (this.root === void 0) {
      return notFound;
    }
    const found = find(this.root, 0, getHash(key2), key2);
    if (found === void 0) {
      return notFound;
    }
    return found.v;
  }
  /**
   * @param {K} key
   * @param {V} val
   * @returns {Dict<K,V>}
   */
  set(key2, val) {
    const addedLeaf = { val: false };
    const root2 = this.root === void 0 ? EMPTY : this.root;
    const newRoot = assoc(root2, 0, getHash(key2), key2, val, addedLeaf);
    if (newRoot === this.root) {
      return this;
    }
    return new _Dict(newRoot, addedLeaf.val ? this.size + 1 : this.size);
  }
  /**
   * @param {K} key
   * @returns {Dict<K,V>}
   */
  delete(key2) {
    if (this.root === void 0) {
      return this;
    }
    const newRoot = without(this.root, 0, getHash(key2), key2);
    if (newRoot === this.root) {
      return this;
    }
    if (newRoot === void 0) {
      return _Dict.new();
    }
    return new _Dict(newRoot, this.size - 1);
  }
  /**
   * @param {K} key
   * @returns {boolean}
   */
  has(key2) {
    if (this.root === void 0) {
      return false;
    }
    return find(this.root, 0, getHash(key2), key2) !== void 0;
  }
  /**
   * @returns {[K,V][]}
   */
  entries() {
    if (this.root === void 0) {
      return [];
    }
    const result = [];
    this.forEach((v, k) => result.push([k, v]));
    return result;
  }
  /**
   *
   * @param {(val:V,key:K)=>void} fn
   */
  forEach(fn) {
    forEach(this.root, fn);
  }
  hashCode() {
    let h = 0;
    this.forEach((v, k) => {
      h = h + hashMerge(getHash(v), getHash(k)) | 0;
    });
    return h;
  }
  /**
   * @param {unknown} o
   * @returns {boolean}
   */
  equals(o) {
    if (!(o instanceof _Dict) || this.size !== o.size) {
      return false;
    }
    let equal = true;
    this.forEach((v, k) => {
      equal = equal && isEqual(o.get(k, !v), v);
    });
    return equal;
  }
};

// build/dev/javascript/gleam_stdlib/gleam_stdlib.mjs
var Nil2 = void 0;
var NOT_FOUND = {};
function identity(x) {
  return x;
}
function parse_int(value4) {
  if (/^[-+]?(\d+)$/.test(value4)) {
    return new Ok2(parseInt(value4));
  } else {
    return new Error2(Nil2);
  }
}
function to_string2(term) {
  return term.toString();
}
function float_to_string(float3) {
  const string3 = float3.toString();
  if (string3.indexOf(".") >= 0) {
    return string3;
  } else {
    return string3 + ".0";
  }
}
function string_replace(string3, target2, substitute) {
  if (typeof string3.replaceAll !== "undefined") {
    return string3.replaceAll(target2, substitute);
  }
  return string3.replace(
    // $& means the whole matched string
    new RegExp(target2.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g"),
    substitute
  );
}
function string_length(string3) {
  if (string3 === "") {
    return 0;
  }
  const iterator = graphemes_iterator(string3);
  if (iterator) {
    let i = 0;
    for (const _ of iterator) {
      i++;
    }
    return i;
  } else {
    return string3.match(/./gsu).length;
  }
}
function graphemes(string3) {
  const iterator = graphemes_iterator(string3);
  if (iterator) {
    return List.fromArray(Array.from(iterator).map((item) => item.segment));
  } else {
    return List.fromArray(string3.match(/./gsu));
  }
}
function graphemes_iterator(string3) {
  if (Intl && Intl.Segmenter) {
    return new Intl.Segmenter().segment(string3)[Symbol.iterator]();
  }
}
function lowercase(string3) {
  return string3.toLowerCase();
}
function add(a2, b) {
  return a2 + b;
}
function split(xs, pattern) {
  return List.fromArray(xs.split(pattern));
}
function join(xs, separator) {
  const iterator = xs[Symbol.iterator]();
  let result = iterator.next().value || "";
  let current = iterator.next();
  while (!current.done) {
    result = result + separator + current.value;
    current = iterator.next();
  }
  return result;
}
function concat(xs) {
  let result = "";
  for (const x of xs) {
    result = result + x;
  }
  return result;
}
function trim(string3) {
  return string3.trim();
}
function print_debug(string3) {
  if (typeof process === "object" && process.stderr?.write) {
    process.stderr.write(string3 + "\n");
  } else if (typeof Deno === "object") {
    Deno.stderr.writeSync(new TextEncoder().encode(string3 + "\n"));
  } else {
    console.log(string3);
  }
}
function new_map() {
  return Dict.new();
}
function map_to_list(map8) {
  return List.fromArray(map8.entries());
}
function map_get(map8, key2) {
  const value4 = map8.get(key2, NOT_FOUND);
  if (value4 === NOT_FOUND) {
    return new Error2(Nil2);
  }
  return new Ok2(value4);
}
function map_insert(key2, value4, map8) {
  return map8.set(key2, value4);
}
function classify_dynamic(data) {
  if (typeof data === "string") {
    return "String";
  } else if (typeof data === "boolean") {
    return "Bool";
  } else if (data instanceof Result) {
    return "Result";
  } else if (data instanceof List) {
    return "List";
  } else if (data instanceof BitArray) {
    return "BitArray";
  } else if (data instanceof Dict) {
    return "Dict";
  } else if (Number.isInteger(data)) {
    return "Int";
  } else if (Array.isArray(data)) {
    return `Tuple of ${data.length} elements`;
  } else if (typeof data === "number") {
    return "Float";
  } else if (data === null) {
    return "Null";
  } else if (data === void 0) {
    return "Nil";
  } else {
    const type = typeof data;
    return type.charAt(0).toUpperCase() + type.slice(1);
  }
}
function decoder_error(expected, got) {
  return decoder_error_no_classify(expected, classify_dynamic(got));
}
function decoder_error_no_classify(expected, got) {
  return new Error2(
    List.fromArray([new DecodeError(expected, got, List.fromArray([]))])
  );
}
function decode_string(data) {
  return typeof data === "string" ? new Ok2(data) : decoder_error("String", data);
}
function decode_int(data) {
  return Number.isInteger(data) ? new Ok2(data) : decoder_error("Int", data);
}
function decode_list(data) {
  if (Array.isArray(data)) {
    return new Ok2(List.fromArray(data));
  }
  return data instanceof List ? new Ok2(data) : decoder_error("List", data);
}
function decode_map(data) {
  if (data instanceof Dict) {
    return new Ok2(data);
  }
  if (data instanceof Map || data instanceof WeakMap) {
    return new Ok2(Dict.fromMap(data));
  }
  if (data == null) {
    return decoder_error("Dict", data);
  }
  if (typeof data !== "object") {
    return decoder_error("Dict", data);
  }
  const proto = Object.getPrototypeOf(data);
  if (proto === Object.prototype || proto === null) {
    return new Ok2(Dict.fromObject(data));
  }
  return decoder_error("Dict", data);
}
function decode_option(data, decoder) {
  if (data === null || data === void 0 || data instanceof None)
    return new Ok2(new None());
  if (data instanceof Some)
    data = data[0];
  const result = decoder(data);
  if (result.isOk()) {
    return new Ok2(new Some(result[0]));
  } else {
    return result;
  }
}
function decode_field(value4, name2) {
  const not_a_map_error = () => decoder_error("Dict", value4);
  if (value4 instanceof Dict || value4 instanceof WeakMap || value4 instanceof Map) {
    const entry = map_get(value4, name2);
    return new Ok2(entry.isOk() ? new Some(entry[0]) : new None());
  } else if (value4 === null) {
    return not_a_map_error();
  } else if (Object.getPrototypeOf(value4) == Object.prototype) {
    return try_get_field(value4, name2, () => new Ok2(new None()));
  } else {
    return try_get_field(value4, name2, not_a_map_error);
  }
}
function try_get_field(value4, field2, or_else) {
  try {
    return field2 in value4 ? new Ok2(new Some(value4[field2])) : or_else();
  } catch {
    return or_else();
  }
}
function inspect(v) {
  const t = typeof v;
  if (v === true)
    return "True";
  if (v === false)
    return "False";
  if (v === null)
    return "//js(null)";
  if (v === void 0)
    return "Nil";
  if (t === "string")
    return JSON.stringify(v);
  if (t === "bigint" || t === "number")
    return v.toString();
  if (Array.isArray(v))
    return `#(${v.map(inspect).join(", ")})`;
  if (v instanceof List)
    return inspectList(v);
  if (v instanceof UtfCodepoint)
    return inspectUtfCodepoint(v);
  if (v instanceof BitArray)
    return inspectBitArray(v);
  if (v instanceof CustomType)
    return inspectCustomType(v);
  if (v instanceof Dict)
    return inspectDict(v);
  if (v instanceof Set)
    return `//js(Set(${[...v].map(inspect).join(", ")}))`;
  if (v instanceof RegExp)
    return `//js(${v})`;
  if (v instanceof Date)
    return `//js(Date("${v.toISOString()}"))`;
  if (v instanceof Function) {
    const args = [];
    for (const i of Array(v.length).keys())
      args.push(String.fromCharCode(i + 97));
    return `//fn(${args.join(", ")}) { ... }`;
  }
  return inspectObject(v);
}
function inspectDict(map8) {
  let body3 = "dict.from_list([";
  let first3 = true;
  map8.forEach((value4, key2) => {
    if (!first3)
      body3 = body3 + ", ";
    body3 = body3 + "#(" + inspect(key2) + ", " + inspect(value4) + ")";
    first3 = false;
  });
  return body3 + "])";
}
function inspectObject(v) {
  const name2 = Object.getPrototypeOf(v)?.constructor?.name || "Object";
  const props = [];
  for (const k of Object.keys(v)) {
    props.push(`${inspect(k)}: ${inspect(v[k])}`);
  }
  const body3 = props.length ? " " + props.join(", ") + " " : "";
  const head = name2 === "Object" ? "" : name2 + " ";
  return `//js(${head}{${body3}})`;
}
function inspectCustomType(record) {
  const props = Object.keys(record).map((label2) => {
    const value4 = inspect(record[label2]);
    return isNaN(parseInt(label2)) ? `${label2}: ${value4}` : value4;
  }).join(", ");
  return props ? `${record.constructor.name}(${props})` : record.constructor.name;
}
function inspectList(list2) {
  return `[${list2.toArray().map(inspect).join(", ")}]`;
}
function inspectBitArray(bits) {
  return `<<${Array.from(bits.buffer).join(", ")}>>`;
}
function inspectUtfCodepoint(codepoint2) {
  return `//utfcodepoint(${String.fromCodePoint(codepoint2.value)})`;
}

// build/dev/javascript/gleam_stdlib/gleam/dict.mjs
function new$() {
  return new_map();
}
function get(from3, get3) {
  return map_get(from3, get3);
}
function insert(dict2, key2, value4) {
  return map_insert(key2, value4, dict2);
}
function fold_list_of_pair(loop$list, loop$initial) {
  while (true) {
    let list2 = loop$list;
    let initial = loop$initial;
    if (list2.hasLength(0)) {
      return initial;
    } else {
      let x = list2.head;
      let rest = list2.tail;
      loop$list = rest;
      loop$initial = insert(initial, x[0], x[1]);
    }
  }
}
function from_list(list2) {
  return fold_list_of_pair(list2, new$());
}
function reverse_and_concat(loop$remaining, loop$accumulator) {
  while (true) {
    let remaining = loop$remaining;
    let accumulator = loop$accumulator;
    if (remaining.hasLength(0)) {
      return accumulator;
    } else {
      let item = remaining.head;
      let rest = remaining.tail;
      loop$remaining = rest;
      loop$accumulator = prepend(item, accumulator);
    }
  }
}
function do_values_acc(loop$list, loop$acc) {
  while (true) {
    let list2 = loop$list;
    let acc = loop$acc;
    if (list2.hasLength(0)) {
      return reverse_and_concat(acc, toList([]));
    } else {
      let x = list2.head;
      let xs = list2.tail;
      loop$list = xs;
      loop$acc = prepend(x[1], acc);
    }
  }
}
function do_values(dict2) {
  let list_of_pairs = map_to_list(dict2);
  return do_values_acc(list_of_pairs, toList([]));
}
function values(dict2) {
  return do_values(dict2);
}
function do_fold(loop$list, loop$initial, loop$fun) {
  while (true) {
    let list2 = loop$list;
    let initial = loop$initial;
    let fun = loop$fun;
    if (list2.hasLength(0)) {
      return initial;
    } else {
      let k = list2.head[0];
      let v = list2.head[1];
      let rest = list2.tail;
      loop$list = rest;
      loop$initial = fun(initial, k, v);
      loop$fun = fun;
    }
  }
}
function fold(dict2, initial, fun) {
  let _pipe = dict2;
  let _pipe$1 = map_to_list(_pipe);
  return do_fold(_pipe$1, initial, fun);
}
function do_map_values(f, dict2) {
  let f$1 = (dict3, k, v) => {
    return insert(dict3, k, f(k, v));
  };
  let _pipe = dict2;
  return fold(_pipe, new$(), f$1);
}
function map_values(dict2, fun) {
  return do_map_values(fun, dict2);
}

// build/dev/javascript/gleam_stdlib/gleam/pair.mjs
function first(pair) {
  let a2 = pair[0];
  return a2;
}
function second(pair) {
  let a2 = pair[1];
  return a2;
}
function new$2(first3, second2) {
  return [first3, second2];
}

// build/dev/javascript/gleam_stdlib/gleam/list.mjs
function do_reverse(loop$remaining, loop$accumulator) {
  while (true) {
    let remaining = loop$remaining;
    let accumulator = loop$accumulator;
    if (remaining.hasLength(0)) {
      return accumulator;
    } else {
      let item = remaining.head;
      let rest$1 = remaining.tail;
      loop$remaining = rest$1;
      loop$accumulator = prepend(item, accumulator);
    }
  }
}
function reverse(xs) {
  return do_reverse(xs, toList([]));
}
function is_empty(list2) {
  return isEqual(list2, toList([]));
}
function first2(list2) {
  if (list2.hasLength(0)) {
    return new Error2(void 0);
  } else {
    let x = list2.head;
    return new Ok2(x);
  }
}
function do_filter(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list2 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list2.hasLength(0)) {
      return reverse(acc);
    } else {
      let x = list2.head;
      let xs = list2.tail;
      let new_acc = (() => {
        let $ = fun(x);
        if ($) {
          return prepend(x, acc);
        } else {
          return acc;
        }
      })();
      loop$list = xs;
      loop$fun = fun;
      loop$acc = new_acc;
    }
  }
}
function filter(list2, predicate) {
  return do_filter(list2, predicate, toList([]));
}
function do_filter_map(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list2 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list2.hasLength(0)) {
      return reverse(acc);
    } else {
      let x = list2.head;
      let xs = list2.tail;
      let new_acc = (() => {
        let $ = fun(x);
        if ($.isOk()) {
          let x$1 = $[0];
          return prepend(x$1, acc);
        } else {
          return acc;
        }
      })();
      loop$list = xs;
      loop$fun = fun;
      loop$acc = new_acc;
    }
  }
}
function filter_map(list2, fun) {
  return do_filter_map(list2, fun, toList([]));
}
function do_map(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list2 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list2.hasLength(0)) {
      return reverse(acc);
    } else {
      let x = list2.head;
      let xs = list2.tail;
      loop$list = xs;
      loop$fun = fun;
      loop$acc = prepend(fun(x), acc);
    }
  }
}
function map3(list2, fun) {
  return do_map(list2, fun, toList([]));
}
function do_index_map(loop$list, loop$fun, loop$index, loop$acc) {
  while (true) {
    let list2 = loop$list;
    let fun = loop$fun;
    let index3 = loop$index;
    let acc = loop$acc;
    if (list2.hasLength(0)) {
      return reverse(acc);
    } else {
      let x = list2.head;
      let xs = list2.tail;
      let acc$1 = prepend(fun(x, index3), acc);
      loop$list = xs;
      loop$fun = fun;
      loop$index = index3 + 1;
      loop$acc = acc$1;
    }
  }
}
function index_map(list2, fun) {
  return do_index_map(list2, fun, 0, toList([]));
}
function do_try_map(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list2 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list2.hasLength(0)) {
      return new Ok2(reverse(acc));
    } else {
      let x = list2.head;
      let xs = list2.tail;
      let $ = fun(x);
      if ($.isOk()) {
        let y = $[0];
        loop$list = xs;
        loop$fun = fun;
        loop$acc = prepend(y, acc);
      } else {
        let error = $[0];
        return new Error2(error);
      }
    }
  }
}
function try_map(list2, fun) {
  return do_try_map(list2, fun, toList([]));
}
function do_take(loop$list, loop$n, loop$acc) {
  while (true) {
    let list2 = loop$list;
    let n = loop$n;
    let acc = loop$acc;
    let $ = n <= 0;
    if ($) {
      return reverse(acc);
    } else {
      if (list2.hasLength(0)) {
        return reverse(acc);
      } else {
        let x = list2.head;
        let xs = list2.tail;
        loop$list = xs;
        loop$n = n - 1;
        loop$acc = prepend(x, acc);
      }
    }
  }
}
function take(list2, n) {
  return do_take(list2, n, toList([]));
}
function do_append(loop$first, loop$second) {
  while (true) {
    let first3 = loop$first;
    let second2 = loop$second;
    if (first3.hasLength(0)) {
      return second2;
    } else {
      let item = first3.head;
      let rest$1 = first3.tail;
      loop$first = rest$1;
      loop$second = prepend(item, second2);
    }
  }
}
function append2(first3, second2) {
  return do_append(reverse(first3), second2);
}
function prepend2(list2, item) {
  return prepend(item, list2);
}
function reverse_and_prepend(loop$prefix, loop$suffix) {
  while (true) {
    let prefix = loop$prefix;
    let suffix = loop$suffix;
    if (prefix.hasLength(0)) {
      return suffix;
    } else {
      let first$1 = prefix.head;
      let rest$1 = prefix.tail;
      loop$prefix = rest$1;
      loop$suffix = prepend(first$1, suffix);
    }
  }
}
function do_concat(loop$lists, loop$acc) {
  while (true) {
    let lists = loop$lists;
    let acc = loop$acc;
    if (lists.hasLength(0)) {
      return reverse(acc);
    } else {
      let list2 = lists.head;
      let further_lists = lists.tail;
      loop$lists = further_lists;
      loop$acc = reverse_and_prepend(list2, acc);
    }
  }
}
function concat2(lists) {
  return do_concat(lists, toList([]));
}
function flat_map(list2, fun) {
  let _pipe = map3(list2, fun);
  return concat2(_pipe);
}
function fold2(loop$list, loop$initial, loop$fun) {
  while (true) {
    let list2 = loop$list;
    let initial = loop$initial;
    let fun = loop$fun;
    if (list2.hasLength(0)) {
      return initial;
    } else {
      let x = list2.head;
      let rest$1 = list2.tail;
      loop$list = rest$1;
      loop$initial = fun(initial, x);
      loop$fun = fun;
    }
  }
}
function fold_right(list2, initial, fun) {
  if (list2.hasLength(0)) {
    return initial;
  } else {
    let x = list2.head;
    let rest$1 = list2.tail;
    return fun(fold_right(rest$1, initial, fun), x);
  }
}
function find2(loop$haystack, loop$is_desired) {
  while (true) {
    let haystack = loop$haystack;
    let is_desired = loop$is_desired;
    if (haystack.hasLength(0)) {
      return new Error2(void 0);
    } else {
      let x = haystack.head;
      let rest$1 = haystack.tail;
      let $ = is_desired(x);
      if ($) {
        return new Ok2(x);
      } else {
        loop$haystack = rest$1;
        loop$is_desired = is_desired;
      }
    }
  }
}
function key_set(list2, key2, value4) {
  if (list2.hasLength(0)) {
    return toList([[key2, value4]]);
  } else if (list2.atLeastLength(1) && isEqual(list2.head[0], key2)) {
    let k = list2.head[0];
    let rest$1 = list2.tail;
    return prepend([key2, value4], rest$1);
  } else {
    let first$1 = list2.head;
    let rest$1 = list2.tail;
    return prepend(first$1, key_set(rest$1, key2, value4));
  }
}

// build/dev/javascript/gleam_stdlib/gleam/iterator.mjs
var Stop = class extends CustomType {
};
var Continue2 = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Iterator = class extends CustomType {
  constructor(continuation) {
    super();
    this.continuation = continuation;
  }
};
var Next = class extends CustomType {
  constructor(element2, accumulator) {
    super();
    this.element = element2;
    this.accumulator = accumulator;
  }
};
function do_unfold(initial, f) {
  return () => {
    let $ = f(initial);
    if ($ instanceof Next) {
      let x = $.element;
      let acc = $.accumulator;
      return new Continue2(x, do_unfold(acc, f));
    } else {
      return new Stop();
    }
  };
}
function unfold(initial, f) {
  let _pipe = initial;
  let _pipe$1 = do_unfold(_pipe, f);
  return new Iterator(_pipe$1);
}
function repeatedly(f) {
  return unfold(void 0, (_) => {
    return new Next(f(), void 0);
  });
}
function repeat(x) {
  return repeatedly(() => {
    return x;
  });
}
function do_fold2(loop$continuation, loop$f, loop$accumulator) {
  while (true) {
    let continuation = loop$continuation;
    let f = loop$f;
    let accumulator = loop$accumulator;
    let $ = continuation();
    if ($ instanceof Continue2) {
      let elem = $[0];
      let next = $[1];
      loop$continuation = next;
      loop$f = f;
      loop$accumulator = f(accumulator, elem);
    } else {
      return accumulator;
    }
  }
}
function fold3(iterator, initial, f) {
  let _pipe = iterator.continuation;
  return do_fold2(_pipe, f, initial);
}
function to_list(iterator) {
  let _pipe = iterator;
  let _pipe$1 = fold3(
    _pipe,
    toList([]),
    (acc, e) => {
      return prepend(e, acc);
    }
  );
  return reverse(_pipe$1);
}
function do_take2(continuation, desired) {
  return () => {
    let $ = desired > 0;
    if (!$) {
      return new Stop();
    } else {
      let $1 = continuation();
      if ($1 instanceof Stop) {
        return new Stop();
      } else {
        let e = $1[0];
        let next = $1[1];
        return new Continue2(e, do_take2(next, desired - 1));
      }
    }
  };
}
function take2(iterator, desired) {
  let _pipe = iterator.continuation;
  let _pipe$1 = do_take2(_pipe, desired);
  return new Iterator(_pipe$1);
}

// build/dev/javascript/gleam_stdlib/gleam/string.mjs
function length2(string3) {
  return string_length(string3);
}
function replace(string3, pattern, substitute) {
  let _pipe = string3;
  let _pipe$1 = from_string(_pipe);
  let _pipe$2 = string_replace(_pipe$1, pattern, substitute);
  return to_string4(_pipe$2);
}
function lowercase2(string3) {
  return lowercase(string3);
}
function append4(first3, second2) {
  let _pipe = first3;
  let _pipe$1 = from_string(_pipe);
  let _pipe$2 = append(_pipe$1, second2);
  return to_string4(_pipe$2);
}
function concat3(strings) {
  let _pipe = strings;
  let _pipe$1 = from_strings(_pipe);
  return to_string4(_pipe$1);
}
function repeat2(string3, times) {
  let _pipe = repeat(string3);
  let _pipe$1 = take2(_pipe, times);
  let _pipe$2 = to_list(_pipe$1);
  return concat3(_pipe$2);
}
function join2(strings, separator) {
  return join(strings, separator);
}
function trim2(string3) {
  return trim(string3);
}
function split3(x, substring) {
  if (substring === "") {
    return graphemes(x);
  } else {
    let _pipe = x;
    let _pipe$1 = from_string(_pipe);
    let _pipe$2 = split2(_pipe$1, substring);
    return map3(_pipe$2, to_string4);
  }
}
function inspect2(term) {
  let _pipe = inspect(term);
  return to_string4(_pipe);
}

// build/dev/javascript/gleam_stdlib/gleam/uri.mjs
var Uri = class extends CustomType {
  constructor(scheme, userinfo, host, port, path, query, fragment2) {
    super();
    this.scheme = scheme;
    this.userinfo = userinfo;
    this.host = host;
    this.port = port;
    this.path = path;
    this.query = query;
    this.fragment = fragment2;
  }
};
function do_remove_dot_segments(loop$input, loop$accumulator) {
  while (true) {
    let input2 = loop$input;
    let accumulator = loop$accumulator;
    if (input2.hasLength(0)) {
      return reverse(accumulator);
    } else {
      let segment = input2.head;
      let rest = input2.tail;
      let accumulator$1 = (() => {
        if (segment === "") {
          let accumulator$12 = accumulator;
          return accumulator$12;
        } else if (segment === ".") {
          let accumulator$12 = accumulator;
          return accumulator$12;
        } else if (segment === ".." && accumulator.hasLength(0)) {
          return toList([]);
        } else if (segment === ".." && accumulator.atLeastLength(1)) {
          let accumulator$12 = accumulator.tail;
          return accumulator$12;
        } else {
          let segment$1 = segment;
          let accumulator$12 = accumulator;
          return prepend(segment$1, accumulator$12);
        }
      })();
      loop$input = rest;
      loop$accumulator = accumulator$1;
    }
  }
}
function remove_dot_segments(input2) {
  return do_remove_dot_segments(input2, toList([]));
}
function path_segments(path) {
  return remove_dot_segments(split3(path, "/"));
}

// build/dev/javascript/gleam_stdlib/gleam/bool.mjs
function to_string5(bool3) {
  if (!bool3) {
    return "False";
  } else {
    return "True";
  }
}
function guard(requirement, consequence, alternative) {
  if (requirement) {
    return consequence;
  } else {
    return alternative();
  }
}

// build/dev/javascript/gleam_json/gleam_json_ffi.mjs
function object(entries) {
  return Object.fromEntries(entries);
}
function identity2(x) {
  return x;
}
function do_null() {
  return null;
}

// build/dev/javascript/gleam_json/gleam/json.mjs
function string2(input2) {
  return identity2(input2);
}
function null$() {
  return do_null();
}
function nullable(input2, inner_type) {
  if (input2 instanceof Some) {
    let value4 = input2[0];
    return inner_type(value4);
  } else {
    return null$();
  }
}
function object2(entries) {
  return object(entries);
}

// build/dev/javascript/lustre/lustre/effect.mjs
var Effect = class extends CustomType {
  constructor(all2) {
    super();
    this.all = all2;
  }
};
function from2(effect) {
  return new Effect(toList([(dispatch2, _) => {
    return effect(dispatch2);
  }]));
}
function none() {
  return new Effect(toList([]));
}
function batch(effects) {
  return new Effect(
    fold2(
      effects,
      toList([]),
      (b, _use1) => {
        let a2 = _use1.all;
        return append2(b, a2);
      }
    )
  );
}
function map4(effect, f) {
  return new Effect(
    map3(
      effect.all,
      (eff) => {
        return (dispatch2, emit2) => {
          return eff((msg) => {
            return dispatch2(f(msg));
          }, emit2);
        };
      }
    )
  );
}

// build/dev/javascript/lustre/lustre/internals/vdom.mjs
var Text = class extends CustomType {
  constructor(content) {
    super();
    this.content = content;
  }
};
var Element = class extends CustomType {
  constructor(key2, namespace, tag, attrs, children, self_closing, void$) {
    super();
    this.key = key2;
    this.namespace = namespace;
    this.tag = tag;
    this.attrs = attrs;
    this.children = children;
    this.self_closing = self_closing;
    this.void = void$;
  }
};
var Map2 = class extends CustomType {
  constructor(subtree) {
    super();
    this.subtree = subtree;
  }
};
var Fragment = class extends CustomType {
  constructor(elements, key2) {
    super();
    this.elements = elements;
    this.key = key2;
  }
};
var Attribute = class extends CustomType {
  constructor(x0, x1, as_property) {
    super();
    this[0] = x0;
    this[1] = x1;
    this.as_property = as_property;
  }
};
var Event = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};

// build/dev/javascript/lustre/lustre/attribute.mjs
function attribute(name2, value4) {
  return new Attribute(name2, from(value4), false);
}
function property(name2, value4) {
  return new Attribute(name2, from(value4), true);
}
function on(name2, handler) {
  return new Event("on" + name2, handler);
}
function map5(attr, f) {
  if (attr instanceof Attribute) {
    let name$1 = attr[0];
    let value$1 = attr[1];
    let as_property = attr.as_property;
    return new Attribute(name$1, value$1, as_property);
  } else {
    let on$1 = attr[0];
    let handler = attr[1];
    return new Event(on$1, (e) => {
      return map2(handler(e), f);
    });
  }
}
function class$(name2) {
  return attribute("class", name2);
}
function none2() {
  return class$("");
}
function classes(names) {
  return attribute(
    "class",
    (() => {
      let _pipe = names;
      let _pipe$1 = filter_map(
        _pipe,
        (class$3) => {
          let $ = class$3[1];
          if ($) {
            return new Ok2(class$3[0]);
          } else {
            return new Error2(void 0);
          }
        }
      );
      return join2(_pipe$1, " ");
    })()
  );
}
function id(name2) {
  return attribute("id", name2);
}
function type_(name2) {
  return attribute("type", name2);
}
function value(val) {
  return attribute("value", val);
}
function checked(is_checked) {
  return property("checked", is_checked);
}
function placeholder(text3) {
  return attribute("placeholder", text3);
}
function selected(is_selected) {
  return property("selected", is_selected);
}
function name(name2) {
  return attribute("name", name2);
}
function for$(id2) {
  return attribute("for", id2);
}
function href(uri) {
  return attribute("href", uri);
}

// build/dev/javascript/lustre/lustre/element.mjs
function element(tag, attrs, children) {
  if (tag === "area") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "base") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "br") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "col") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "embed") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "hr") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "img") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "input") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "link") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "meta") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "param") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "source") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "track") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "wbr") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else {
    return new Element("", "", tag, attrs, children, false, false);
  }
}
function do_keyed(el2, key2) {
  if (el2 instanceof Element) {
    let namespace = el2.namespace;
    let tag = el2.tag;
    let attrs = el2.attrs;
    let children = el2.children;
    let self_closing = el2.self_closing;
    let void$ = el2.void;
    return new Element(
      key2,
      namespace,
      tag,
      attrs,
      children,
      self_closing,
      void$
    );
  } else if (el2 instanceof Map2) {
    let subtree = el2.subtree;
    return new Map2(() => {
      return do_keyed(subtree(), key2);
    });
  } else if (el2 instanceof Fragment) {
    let elements = el2.elements;
    let _pipe = elements;
    let _pipe$1 = index_map(
      _pipe,
      (element2, idx) => {
        if (element2 instanceof Element) {
          let el_key = element2.key;
          let new_key = (() => {
            if (el_key === "") {
              return key2 + "-" + to_string3(idx);
            } else {
              return key2 + "-" + el_key;
            }
          })();
          return do_keyed(element2, new_key);
        } else {
          return do_keyed(element2, key2);
        }
      }
    );
    return new Fragment(_pipe$1, key2);
  } else {
    return el2;
  }
}
function keyed(el2, children) {
  return el2(
    map3(
      children,
      (_use0) => {
        let key2 = _use0[0];
        let child = _use0[1];
        return do_keyed(child, key2);
      }
    )
  );
}
function text(content) {
  return new Text(content);
}
function none3() {
  return new Text("");
}
function flatten_fragment_elements(elements) {
  return fold_right(
    elements,
    toList([]),
    (new_elements, element2) => {
      if (element2 instanceof Fragment) {
        let fr_elements = element2.elements;
        return append2(fr_elements, new_elements);
      } else {
        let el2 = element2;
        return prepend(el2, new_elements);
      }
    }
  );
}
function fragment(elements) {
  let _pipe = flatten_fragment_elements(elements);
  return new Fragment(_pipe, "");
}
function map6(element2, f) {
  if (element2 instanceof Text) {
    let content = element2.content;
    return new Text(content);
  } else if (element2 instanceof Map2) {
    let subtree = element2.subtree;
    return new Map2(() => {
      return map6(subtree(), f);
    });
  } else if (element2 instanceof Element) {
    let key2 = element2.key;
    let namespace = element2.namespace;
    let tag = element2.tag;
    let attrs = element2.attrs;
    let children = element2.children;
    let self_closing = element2.self_closing;
    let void$ = element2.void;
    return new Map2(
      () => {
        return new Element(
          key2,
          namespace,
          tag,
          map3(
            attrs,
            (_capture) => {
              return map5(_capture, f);
            }
          ),
          map3(children, (_capture) => {
            return map6(_capture, f);
          }),
          self_closing,
          void$
        );
      }
    );
  } else {
    let elements = element2.elements;
    let key2 = element2.key;
    return new Map2(
      () => {
        return new Fragment(
          map3(elements, (_capture) => {
            return map6(_capture, f);
          }),
          key2
        );
      }
    );
  }
}

// build/dev/javascript/gleam_stdlib/gleam/io.mjs
function debug(term) {
  let _pipe = term;
  let _pipe$1 = inspect2(_pipe);
  print_debug(_pipe$1);
  return term;
}

// build/dev/javascript/lustre/lustre/internals/runtime.mjs
var Debug = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Dispatch = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Shutdown = class extends CustomType {
};
var ForceModel = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};

// build/dev/javascript/lustre/vdom.ffi.mjs
function morph(prev, next, dispatch2, isComponent = false) {
  let out;
  let stack = [{ prev, next, parent: prev.parentNode }];
  while (stack.length) {
    let { prev: prev2, next: next2, parent } = stack.pop();
    if (next2.subtree !== void 0)
      next2 = next2.subtree();
    if (next2.content !== void 0) {
      if (!prev2) {
        const created = document.createTextNode(next2.content);
        parent.appendChild(created);
        out ??= created;
      } else if (prev2.nodeType === Node.TEXT_NODE) {
        if (prev2.textContent !== next2.content)
          prev2.textContent = next2.content;
        out ??= prev2;
      } else {
        const created = document.createTextNode(next2.content);
        parent.replaceChild(created, prev2);
        out ??= created;
      }
    } else if (next2.tag !== void 0) {
      const created = createElementNode({
        prev: prev2,
        next: next2,
        dispatch: dispatch2,
        stack,
        isComponent
      });
      if (!prev2) {
        parent.appendChild(created);
      } else if (prev2 !== created) {
        parent.replaceChild(created, prev2);
      }
      out ??= created;
    } else if (next2.elements !== void 0) {
      iterateElement(next2, (fragmentElement) => {
        stack.unshift({ prev: prev2, next: fragmentElement, parent });
        prev2 = prev2?.nextSibling;
      });
    } else if (next2.subtree !== void 0) {
      stack.push({ prev: prev2, next: next2, parent });
    }
  }
  return out;
}
function createElementNode({ prev, next, dispatch: dispatch2, stack }) {
  const namespace = next.namespace || "http://www.w3.org/1999/xhtml";
  const canMorph = prev && prev.nodeType === Node.ELEMENT_NODE && prev.localName === next.tag && prev.namespaceURI === (next.namespace || "http://www.w3.org/1999/xhtml");
  const el2 = canMorph ? prev : namespace ? document.createElementNS(namespace, next.tag) : document.createElement(next.tag);
  let handlersForEl;
  if (!registeredHandlers.has(el2)) {
    const emptyHandlers = /* @__PURE__ */ new Map();
    registeredHandlers.set(el2, emptyHandlers);
    handlersForEl = emptyHandlers;
  } else {
    handlersForEl = registeredHandlers.get(el2);
  }
  const prevHandlers = canMorph ? new Set(handlersForEl.keys()) : null;
  const prevAttributes = canMorph ? new Set(Array.from(prev.attributes, (a2) => a2.name)) : null;
  let className = null;
  let style2 = null;
  let innerHTML = null;
  for (const attr of next.attrs) {
    const name2 = attr[0];
    const value4 = attr[1];
    if (attr.as_property) {
      if (el2[name2] !== value4)
        el2[name2] = value4;
      if (canMorph)
        prevAttributes.delete(name2);
    } else if (name2.startsWith("on")) {
      const eventName = name2.slice(2);
      const callback = dispatch2(value4);
      if (!handlersForEl.has(eventName)) {
        el2.addEventListener(eventName, lustreGenericEventHandler);
      }
      handlersForEl.set(eventName, callback);
      if (canMorph)
        prevHandlers.delete(eventName);
    } else if (name2.startsWith("data-lustre-on-")) {
      const eventName = name2.slice(15);
      const callback = dispatch2(lustreServerEventHandler);
      if (!handlersForEl.has(eventName)) {
        el2.addEventListener(eventName, lustreGenericEventHandler);
      }
      handlersForEl.set(eventName, callback);
      el2.setAttribute(name2, value4);
    } else if (name2 === "class") {
      className = className === null ? value4 : className + " " + value4;
    } else if (name2 === "style") {
      style2 = style2 === null ? value4 : style2 + value4;
    } else if (name2 === "dangerous-unescaped-html") {
      innerHTML = value4;
    } else {
      if (typeof value4 === "string")
        el2.setAttribute(name2, value4);
      if (name2 === "value" || name2 === "selected")
        el2[name2] = value4;
      if (canMorph)
        prevAttributes.delete(name2);
    }
  }
  if (className !== null) {
    el2.setAttribute("class", className);
    if (canMorph)
      prevAttributes.delete("class");
  }
  if (style2 !== null) {
    el2.setAttribute("style", style2);
    if (canMorph)
      prevAttributes.delete("style");
  }
  if (canMorph) {
    for (const attr of prevAttributes) {
      el2.removeAttribute(attr);
    }
    for (const eventName of prevHandlers) {
      handlersForEl.delete(eventName);
      el2.removeEventListener(eventName, lustreGenericEventHandler);
    }
  }
  if (next.key !== void 0 && next.key !== "") {
    el2.setAttribute("data-lustre-key", next.key);
  } else if (innerHTML !== null) {
    el2.innerHTML = innerHTML;
    return el2;
  }
  let prevChild = el2.firstChild;
  let seenKeys = null;
  let keyedChildren = null;
  let incomingKeyedChildren = null;
  let firstChild = next.children[Symbol.iterator]().next().value;
  if (canMorph && firstChild !== void 0 && // Explicit checks are more verbose but truthy checks force a bunch of comparisons
  // we don't care about: it's never gonna be a number etc.
  firstChild.key !== void 0 && firstChild.key !== "") {
    seenKeys = /* @__PURE__ */ new Set();
    keyedChildren = getKeyedChildren(prev);
    incomingKeyedChildren = getKeyedChildren(next);
  }
  for (const child of next.children) {
    iterateElement(child, (currElement) => {
      if (currElement.key !== void 0 && seenKeys !== null) {
        prevChild = diffKeyedChild(
          prevChild,
          currElement,
          el2,
          stack,
          incomingKeyedChildren,
          keyedChildren,
          seenKeys
        );
      } else {
        stack.unshift({ prev: prevChild, next: currElement, parent: el2 });
        prevChild = prevChild?.nextSibling;
      }
    });
  }
  while (prevChild) {
    const next2 = prevChild.nextSibling;
    el2.removeChild(prevChild);
    prevChild = next2;
  }
  return el2;
}
var registeredHandlers = /* @__PURE__ */ new WeakMap();
function lustreGenericEventHandler(event2) {
  const target2 = event2.currentTarget;
  if (!registeredHandlers.has(target2)) {
    target2.removeEventListener(event2.type, lustreGenericEventHandler);
    return;
  }
  const handlersForEventTarget = registeredHandlers.get(target2);
  if (!handlersForEventTarget.has(event2.type)) {
    target2.removeEventListener(event2.type, lustreGenericEventHandler);
    return;
  }
  handlersForEventTarget.get(event2.type)(event2);
}
function lustreServerEventHandler(event2) {
  const el2 = event2.target;
  const tag = el2.getAttribute(`data-lustre-on-${event2.type}`);
  const data = JSON.parse(el2.getAttribute("data-lustre-data") || "{}");
  const include = JSON.parse(el2.getAttribute("data-lustre-include") || "[]");
  switch (event2.type) {
    case "input":
    case "change":
      include.push("target.value");
      break;
  }
  return {
    tag,
    data: include.reduce(
      (data2, property3) => {
        const path = property3.split(".");
        for (let i = 0, o = data2, e = event2; i < path.length; i++) {
          if (i === path.length - 1) {
            o[path[i]] = e[path[i]];
          } else {
            o[path[i]] ??= {};
            e = e[path[i]];
            o = o[path[i]];
          }
        }
        return data2;
      },
      { data }
    )
  };
}
function getKeyedChildren(el2) {
  const keyedChildren = /* @__PURE__ */ new Map();
  if (el2) {
    for (const child of el2.children) {
      iterateElement(child, (currElement) => {
        const key2 = currElement?.key || currElement?.getAttribute?.("data-lustre-key");
        if (key2)
          keyedChildren.set(key2, currElement);
      });
    }
  }
  return keyedChildren;
}
function diffKeyedChild(prevChild, child, el2, stack, incomingKeyedChildren, keyedChildren, seenKeys) {
  while (prevChild && !incomingKeyedChildren.has(prevChild.getAttribute("data-lustre-key"))) {
    const nextChild = prevChild.nextSibling;
    el2.removeChild(prevChild);
    prevChild = nextChild;
  }
  if (keyedChildren.size === 0) {
    iterateElement(child, (currChild) => {
      stack.unshift({ prev: prevChild, next: currChild, parent: el2 });
      prevChild = prevChild?.nextSibling;
    });
    return prevChild;
  }
  if (seenKeys.has(child.key)) {
    console.warn(`Duplicate key found in Lustre vnode: ${child.key}`);
    stack.unshift({ prev: null, next: child, parent: el2 });
    return prevChild;
  }
  seenKeys.add(child.key);
  const keyedChild = keyedChildren.get(child.key);
  if (!keyedChild && !prevChild) {
    stack.unshift({ prev: null, next: child, parent: el2 });
    return prevChild;
  }
  if (!keyedChild && prevChild !== null) {
    const placeholder2 = document.createTextNode("");
    el2.insertBefore(placeholder2, prevChild);
    stack.unshift({ prev: placeholder2, next: child, parent: el2 });
    return prevChild;
  }
  if (!keyedChild || keyedChild === prevChild) {
    stack.unshift({ prev: prevChild, next: child, parent: el2 });
    prevChild = prevChild?.nextSibling;
    return prevChild;
  }
  el2.insertBefore(keyedChild, prevChild);
  stack.unshift({ prev: keyedChild, next: child, parent: el2 });
  return prevChild;
}
function iterateElement(element2, processElement) {
  if (element2.elements !== void 0) {
    for (const currElement of element2.elements) {
      processElement(currElement);
    }
  } else {
    processElement(element2);
  }
}

// build/dev/javascript/lustre/client-runtime.ffi.mjs
var LustreClientApplication2 = class _LustreClientApplication {
  #root = null;
  #queue = [];
  #effects = [];
  #didUpdate = false;
  #isComponent = false;
  #model = null;
  #update = null;
  #view = null;
  static start(flags, selector, init7, update4, view3) {
    if (!is_browser())
      return new Error2(new NotABrowser());
    const root2 = selector instanceof HTMLElement ? selector : document.querySelector(selector);
    if (!root2)
      return new Error2(new ElementNotFound(selector));
    const app = new _LustreClientApplication(init7(flags), update4, view3, root2);
    return new Ok2((msg) => app.send(msg));
  }
  constructor([model, effects], update4, view3, root2 = document.body, isComponent = false) {
    this.#model = model;
    this.#update = update4;
    this.#view = view3;
    this.#root = root2;
    this.#effects = effects.all.toArray();
    this.#didUpdate = true;
    this.#isComponent = isComponent;
    window.requestAnimationFrame(() => this.#tick());
  }
  send(action) {
    switch (true) {
      case action instanceof Dispatch: {
        this.#queue.push(action[0]);
        this.#tick();
        return;
      }
      case action instanceof Shutdown: {
        this.#shutdown();
        return;
      }
      case action instanceof Debug: {
        this.#debug(action[0]);
        return;
      }
      default:
        return;
    }
  }
  emit(event2, data) {
    this.#root.dispatchEvent(
      new CustomEvent(event2, {
        bubbles: true,
        detail: data,
        composed: true
      })
    );
  }
  #tick() {
    this.#flush_queue();
    const vdom = this.#view(this.#model);
    const dispatch2 = (handler) => (e) => {
      const result = handler(e);
      if (result instanceof Ok2) {
        this.send(new Dispatch(result[0]));
      }
    };
    this.#didUpdate = false;
    this.#root = morph(this.#root, vdom, dispatch2, this.#isComponent);
  }
  #flush_queue(iterations = 0) {
    while (this.#queue.length) {
      const [next, effects] = this.#update(this.#model, this.#queue.shift());
      this.#didUpdate ||= !isEqual(this.#model, next);
      this.#model = next;
      this.#effects = this.#effects.concat(effects.all.toArray());
    }
    while (this.#effects.length) {
      this.#effects.shift()(
        (msg) => this.send(new Dispatch(msg)),
        (event2, data) => this.emit(event2, data)
      );
    }
    if (this.#queue.length) {
      if (iterations < 5) {
        this.#flush_queue(++iterations);
      } else {
        window.requestAnimationFrame(() => this.#tick());
      }
    }
  }
  #debug(action) {
    switch (true) {
      case action instanceof ForceModel: {
        const vdom = this.#view(action[0]);
        const dispatch2 = (handler) => (e) => {
          const result = handler(e);
          if (result instanceof Ok2) {
            this.send(new Dispatch(result[0]));
          }
        };
        this.#queue = [];
        this.#effects = [];
        this.#didUpdate = false;
        this.#root = morph(this.#root, vdom, dispatch2, this.#isComponent);
      }
    }
  }
  #shutdown() {
    this.#root.remove();
    this.#root = null;
    this.#model = null;
    this.#queue = [];
    this.#effects = [];
    this.#didUpdate = false;
    this.#update = () => {
    };
    this.#view = () => {
    };
  }
};
var start = (app, selector, flags) => LustreClientApplication2.start(
  flags,
  selector,
  app.init,
  app.update,
  app.view
);
var is_browser = () => window && window.document;
var prevent_default = (event2) => event2.preventDefault();

// build/dev/javascript/lustre/lustre.mjs
var App = class extends CustomType {
  constructor(init7, update4, view3, on_attribute_change) {
    super();
    this.init = init7;
    this.update = update4;
    this.view = view3;
    this.on_attribute_change = on_attribute_change;
  }
};
var ElementNotFound = class extends CustomType {
  constructor(selector) {
    super();
    this.selector = selector;
  }
};
var NotABrowser = class extends CustomType {
};
function application(init7, update4, view3) {
  return new App(init7, update4, view3, new None());
}
function dispatch(msg) {
  return new Dispatch(msg);
}
function start3(app, selector, flags) {
  return guard(
    !is_browser(),
    new Error2(new NotABrowser()),
    () => {
      return start(app, selector, flags);
    }
  );
}

// build/dev/javascript/lustre/lustre/element/html.mjs
function text2(content) {
  return text(content);
}
function h1(attrs, children) {
  return element("h1", attrs, children);
}
function main(attrs, children) {
  return element("main", attrs, children);
}
function nav(attrs, children) {
  return element("nav", attrs, children);
}
function section(attrs, children) {
  return element("section", attrs, children);
}
function div(attrs, children) {
  return element("div", attrs, children);
}
function li(attrs, children) {
  return element("li", attrs, children);
}
function ol(attrs, children) {
  return element("ol", attrs, children);
}
function a(attrs, children) {
  return element("a", attrs, children);
}
function span(attrs, children) {
  return element("span", attrs, children);
}
function button(attrs, children) {
  return element("button", attrs, children);
}
function fieldset(attrs, children) {
  return element("fieldset", attrs, children);
}
function form(attrs, children) {
  return element("form", attrs, children);
}
function input(attrs) {
  return element("input", attrs, toList([]));
}
function label(attrs, children) {
  return element("label", attrs, children);
}
function legend(attrs, children) {
  return element("legend", attrs, children);
}
function option(attrs, label2) {
  return element("option", attrs, toList([text(label2)]));
}
function select(attrs, children) {
  return element("select", attrs, children);
}
function textarea(attrs, content) {
  return element("textarea", attrs, toList([text(content)]));
}

// build/dev/javascript/modem/modem.ffi.mjs
var defaults = {
  handle_external_links: false,
  handle_internal_links: true
};
var initial_location = window?.location?.href;
var do_init = (dispatch2, options = defaults) => {
  document.body.addEventListener("click", (event2) => {
    const a2 = find_anchor(event2.target);
    if (!a2)
      return;
    try {
      const url = new URL(a2.href);
      const uri = uri_from_url(url);
      const is_external = url.host !== window.location.host;
      if (!options.handle_external_links && is_external)
        return;
      if (!options.handle_internal_links && !is_external)
        return;
      event2.preventDefault();
      if (!is_external) {
        window.history.pushState({}, "", a2.href);
        window.requestAnimationFrame(() => {
          if (url.hash) {
            document.getElementById(url.hash.slice(1))?.scrollIntoView();
          }
        });
      }
      return dispatch2(uri);
    } catch {
      return;
    }
  });
  window.addEventListener("popstate", (e) => {
    e.preventDefault();
    const url = new URL(window.location.href);
    const uri = uri_from_url(url);
    window.requestAnimationFrame(() => {
      if (url.hash) {
        document.getElementById(url.hash.slice(1))?.scrollIntoView();
      }
    });
    dispatch2(uri);
  });
};
var find_anchor = (el2) => {
  if (el2.tagName === "BODY") {
    return null;
  } else if (el2.tagName === "A") {
    return el2;
  } else {
    return find_anchor(el2.parentElement);
  }
};
var uri_from_url = (url) => {
  return new Uri(
    /* scheme   */
    url.protocol ? new Some(url.protocol) : new None(),
    /* userinfo */
    new None(),
    /* host     */
    url.host ? new Some(url.host) : new None(),
    /* port     */
    url.port ? new Some(Number(url.port)) : new None(),
    /* path     */
    url.pathname,
    /* query    */
    url.search ? new Some(url.search.slice(1)) : new None(),
    /* fragment */
    url.hash ? new Some(url.hash.slice(1)) : new None()
  );
};

// build/dev/javascript/modem/modem.mjs
function init2(handler) {
  return from2(
    (dispatch2) => {
      return guard(
        !is_browser(),
        void 0,
        () => {
          return do_init(
            (uri) => {
              let _pipe = uri;
              let _pipe$1 = handler(_pipe);
              return dispatch2(_pipe$1);
            }
          );
        }
      );
    }
  );
}

// build/dev/javascript/gleam_stdlib/gleam/function.mjs
function curry2(fun) {
  return (a2) => {
    return (b) => {
      return fun(a2, b);
    };
  };
}
function apply1(fun, arg1) {
  return fun(arg1);
}

// build/dev/javascript/lustre/lustre/event.mjs
function on2(name2, handler) {
  return on(name2, handler);
}
function on_click(msg) {
  return on2("click", (_) => {
    return new Ok2(msg);
  });
}
function value2(event2) {
  let _pipe = event2;
  return field("target", field("value", string))(
    _pipe
  );
}
function on_input(msg) {
  return on2(
    "input",
    (event2) => {
      let _pipe = value2(event2);
      return map2(_pipe, msg);
    }
  );
}
function on_submit(msg) {
  return on2(
    "submit",
    (event2) => {
      let $ = prevent_default(event2);
      return new Ok2(msg);
    }
  );
}

// build/dev/javascript/sketch/helpers.ffi.mjs
var uid = /* @__PURE__ */ function() {
  let id2 = 0;
  const classNames = {};
  return function(className) {
    classNames[className] ??= (id2++).toString().padStart(4, "0");
    const index3 = classNames[className];
    return `css-${index3}`;
  };
}();
function getFunctionName() {
  const error = new Error();
  if (!error.stack)
    throw new Error("Unable to find the stacktrace and to infer the className");
  const stack = error.stack ?? "";
  const parts = stack.split("\n");
  const end = parts.findIndex((l) => l.includes("LustreClientApplication"));
  const endIndex = end === -1 ? parts.length : end;
  const st = parts.slice(1, endIndex).join("\n");
  return st;
}
function deepEqual(a2, b) {
  const consts = ["string", "number", "boolean"];
  if (consts.includes(typeof a2) || consts.includes(typeof b))
    return a2 === b;
  for (const value4 in a2) {
    if (!(value4 in b))
      return false;
    const isSame = deepEqual(a2[value4], b[value4]);
    if (!isSame)
      return false;
  }
  return true;
}
function isBrowser() {
  if (typeof window === "undefined")
    return false;
  if (typeof document === "undefined")
    return false;
  return true;
}

// build/dev/javascript/sketch/sketch/error.mjs
var NotABrowser2 = class extends CustomType {
};

// build/dev/javascript/gleam_javascript/ffi.mjs
function toArray(list2) {
  return list2.toArray();
}
var PromiseLayer = class _PromiseLayer {
  constructor(promise) {
    this.promise = promise;
  }
  static wrap(value4) {
    return value4 instanceof Promise ? new _PromiseLayer(value4) : value4;
  }
  static unwrap(value4) {
    return value4 instanceof _PromiseLayer ? value4.promise : value4;
  }
};
function map_promise(promise, fn) {
  return promise.then(
    (value4) => PromiseLayer.wrap(fn(PromiseLayer.unwrap(value4)))
  );
}

// build/dev/javascript/gleam_javascript/gleam/javascript/promise.mjs
function tap(promise, callback) {
  let _pipe = promise;
  return map_promise(
    _pipe,
    (a2) => {
      callback(a2);
      return a2;
    }
  );
}

// build/dev/javascript/plinth/element_ffi.mjs
function setAttribute(element2, name2, value4) {
  element2.setAttribute(name2, value4);
}
function appendChild(parent, child) {
  parent.appendChild(child);
}

// build/dev/javascript/plinth/shadow_ffi.mjs
function appendChild2(root2, element2) {
  root2.appendChild(element2);
}
function attachShadow(element2, mode) {
  const shadowMode = mode instanceof Open ? "open" : "closed";
  return element2.attachShadow({ mode: shadowMode });
}

// build/dev/javascript/plinth/plinth/browser/shadow.mjs
var Open = class extends CustomType {
};

// build/dev/javascript/sketch/sketch/options.mjs
var Node2 = class extends CustomType {
};
var Document = class extends CustomType {
};
var Shadow = class extends CustomType {
  constructor(root2) {
    super();
    this.root = root2;
  }
};
var Options2 = class extends CustomType {
  constructor(stylesheet2) {
    super();
    this.stylesheet = stylesheet2;
  }
};
function shadow(root2) {
  return new Options2(new Shadow(root2));
}
function stylesheet_to_string(stylesheet2) {
  if (stylesheet2 instanceof Node2) {
    return "node";
  } else if (stylesheet2 instanceof Document) {
    return "document";
  } else {
    return "shadow-root";
  }
}

// build/dev/javascript/sketch/stylesheet.ffi.mjs
var StyleSheet = class {
  static for(type) {
    switch (stylesheet_to_string(type)) {
      case "node":
        return new NodeStyleSheet();
      case "document":
        return new DocumentStyleSheet();
      case "shadow-root":
        return new ShadowStyleSheet(type.root);
    }
  }
};
var AbstractSheet = class {
  #rules;
  #index;
  constructor() {
    this.#rules = /* @__PURE__ */ new Map();
    this.#index = 0;
  }
  insertRule(definition) {
    const index3 = this.#index++;
    this.#rules.set(index3, definition);
    return index3;
  }
  deleteRule(index3) {
    this.#rules.delete(index3);
  }
  buildRules() {
    return [...this.#rules.values()].join("\n\n");
  }
};
var NodeStyleSheet = class extends AbstractSheet {
  #styleElement;
  constructor() {
    super();
    this.#styleElement = document.createElement("style");
    this.#styleElement.setAttribute("class", "sketch-stylesheet");
    document.head.appendChild(this.#styleElement);
  }
  render() {
    const rules2 = this.buildRules();
    this.#styleElement.innerHTML = rules2;
  }
};
var DocumentStyleSheet = class extends AbstractSheet {
  #styleElement;
  constructor() {
    super();
    this.#styleElement = new CSSStyleSheet();
    document.adoptedStyleSheets.push(this.#styleElement);
  }
  render() {
    const rules2 = this.buildRules();
    this.#styleElement.replaceSync(rules2);
  }
};
var ShadowStyleSheet = class extends AbstractSheet {
  #styleElement;
  constructor(shadowRoot) {
    super();
    this.#styleElement = new CSSStyleSheet();
    shadowRoot.adoptedStyleSheets.push(this.#styleElement);
  }
  render() {
    const rules2 = this.buildRules();
    this.#styleElement.replaceSync(rules2);
  }
};

// build/dev/javascript/sketch/cache.ffi.mjs
var cache;
var Cache = class _Cache {
  #memoCache;
  #activeCache;
  #passiveCache;
  #stylesheet;
  constructor(options) {
    this.#memoCache = /* @__PURE__ */ new Map();
    this.#activeCache = /* @__PURE__ */ new Map();
    this.#passiveCache = /* @__PURE__ */ new Map();
    this.#stylesheet = StyleSheet.for(options.stylesheet);
  }
  static create(options) {
    const stylesheetType = stylesheet_to_string(options.stylesheet);
    const isBrowserOnly = ["document", "shadow-root"].includes(stylesheetType);
    if (isBrowserOnly && !isBrowser())
      return new Error2(new NotABrowser2());
    return new _Cache(options);
  }
  prepare() {
    this.#passiveCache = this.#activeCache;
    this.#activeCache = /* @__PURE__ */ new Map();
  }
  // Compute the predefined classes C = (Keys(Old) ∩ Keys(New))
  // Remove the keys defined by Keys(Old) - C.
  // Insert the keys defined by Keys(New) - C.
  diff() {
    const keys2 = /* @__PURE__ */ new Set();
    for (const key2 of this.#activeCache.keys())
      keys2.add(key2);
    for (const key2 of this.#passiveCache.keys())
      keys2.add(key2);
    keys2.forEach((key2) => {
      if (this.#activeCache.has(key2)) {
        const klass = this.#activeCache.get(key2);
        if (klass?.indexRules !== null)
          return;
        return this.#insertStyles(klass);
      }
      if (this.#passiveCache.has(key2))
        return this.#deleteStyles(this.#passiveCache.get(key2));
    });
    this.#stylesheet.render();
  }
  persist(className, properties) {
    const memoizedContent = this.#memoCache.get(className);
    if (memoizedContent)
      return { name: memoizedContent.name, className };
    const newContent = this.#activeCache.get(className);
    if (newContent)
      return { name: newContent.name, className };
    const oldContent = this.#passiveCache.get(className);
    if (oldContent && deepEqual(properties, oldContent.previousStyles)) {
      this.#activeCache.set(className, oldContent);
      return { name: oldContent.name, className };
    }
  }
  // Store the newly computed class.
  // className: string
  // content: {
  //   name: string,
  //   previousStyles: List(Style),
  //   indexRules: number[] | null,
  //   definitions: { medias_def: string, selectors_def: string, class_def: string },
  // }
  store(className, content) {
    this.#activeCache.set(className, content);
  }
  // Memoize a class in order to avoid multiple recomputations of properties.
  // It saves the content of the class right away in the browser, and will never
  // recompute them later.
  memoize({ className }) {
    if (this.#memoCache.has(className))
      return;
    const klass = this.#activeCache.get(className);
    this.#memoCache.set(className, klass);
    this.#activeCache.delete(className);
    if (klass.indexRules === null) {
      this.#insertStyles(klass);
    }
  }
  // Insert the styles in the stylesheet.
  // It inserts medias, selectors and index rules. It inserts first the rule,
  // then the selectors, and then the media, to respect the usual order in a
  // standard CSS sheet, and to respect precedence of the styles.
  #insertStyles(klass) {
    const indexRules = [];
    const { definitions: definitions2 } = klass;
    indexRules.push(this.#stylesheet.insertRule(definitions2.class_def));
    for (const def of definitions2.selectors_def)
      indexRules.push(this.#stylesheet.insertRule(def));
    for (const def of definitions2.medias_def)
      indexRules.push(this.#stylesheet.insertRule(def));
    klass.indexRules = indexRules;
  }
  #deleteStyles(klass) {
    klass.indexRules?.forEach((indexRule) => {
      this.#stylesheet.deleteRule(indexRule);
    });
  }
};
function createCache(options) {
  const newCache = Cache.create(options);
  if (newCache instanceof Cache)
    cache = newCache;
  return new Ok2(newCache);
}
function prepareCache(cache_) {
  cache = cache_;
  cache.prepare();
}
function renderCache(cache2) {
  cache2.diff();
  return new Error2(null);
}

// build/dev/javascript/sketch/errors.ffi.mjs
var warningDisplayed = false;
var lifecycleMissing = "Sketch lifecycles setup is missing.";
var lifecycleFunctions = `If you're not using lustre, you should use directly the lifecycle functions:
  - create_cache (https://hexdocs.pm/sketch/sketch.html#create_cache)
  - prepare (https://hexdocs.pm/sketch/sketch.html#prepare)
  - render (https://hexdocs.pm/sketch/sketch.html#render)

// main.gleam
// Assuming your framework have a lifecycle, here's a fictive example.

import sketch
import sketch/options as sketch_options

pub fn main() {
  let assert Ok(cache) = sketch.create_cache()
  start_app()
  |> add_before_render(fn () { sketch.prepare(cache) })
  |> add_after_render(fn () { sketch.render(cache) })
}
`;
var lustreSetup = `// main.gleam
// If you're using lustre, initialize Sketch in your main().

import sketch/lustre as sketch_lustre
import sketch/options as sketch_options

pub fn main() {
  let assert Ok(cache) =
    sketch_options.node()
    |> sketch_lustre.setup()

  let assert Ok(_) =
    view
    |> sketch_lustre.compose(cache)
    |> lustre.simple(init, update, _)
    |> lustre.start("#app", Nil)

}
`;
var warn = {
  setup() {
    if (warningDisplayed)
      return;
    const notRender = "Meanwhile, styles won\u2019t apply, but will not block your render.";
    const documentation = "More informations on https://hexdocs.pm/sketch.";
    console.warn(lifecycleMissing);
    console.warn(lustreSetup);
    console.warn(lifecycleFunctions);
    console.warn(notRender);
    console.warn(documentation);
    warningDisplayed = true;
  }
};

// build/dev/javascript/sketch/sketch/internals/string.mjs
function indent(indent2) {
  return repeat2(" ", indent2);
}
function wrap_class(id2, properties, idt, pseudo) {
  let base_indent = indent(idt);
  let pseudo_ = unwrap(pseudo, "");
  let _pipe = prepend(
    base_indent + "." + id2 + pseudo_ + " {",
    properties
  );
  let _pipe$1 = join2(_pipe, "\n");
  return append4(_pipe$1, "\n" + base_indent + "}");
}

// build/dev/javascript/sketch/sketch/internals/style.mjs
var ClassName = class extends CustomType {
  constructor(class_name) {
    super();
    this.class_name = class_name;
  }
};
var Media = class extends CustomType {
  constructor(query, styles) {
    super();
    this.query = query;
    this.styles = styles;
  }
};
var PseudoSelector = class extends CustomType {
  constructor(pseudo_selector, styles) {
    super();
    this.pseudo_selector = pseudo_selector;
    this.styles = styles;
  }
};
var Property = class extends CustomType {
  constructor(key2, value4, important) {
    super();
    this.key = key2;
    this.value = value4;
    this.important = important;
  }
};
var ComputedProperties = class extends CustomType {
  constructor(properties, medias, classes2, pseudo_selectors, indent2) {
    super();
    this.properties = properties;
    this.medias = medias;
    this.classes = classes2;
    this.pseudo_selectors = pseudo_selectors;
    this.indent = indent2;
  }
};
var MediaProperty = class extends CustomType {
  constructor(query, properties, pseudo_selectors) {
    super();
    this.query = query;
    this.properties = properties;
    this.pseudo_selectors = pseudo_selectors;
  }
};
var PseudoProperty = class extends CustomType {
  constructor(pseudo_selector, properties) {
    super();
    this.pseudo_selector = pseudo_selector;
    this.properties = properties;
  }
};
var ComputedClass = class extends CustomType {
  constructor(class_def, medias_def, selectors_def, name2) {
    super();
    this.class_def = class_def;
    this.medias_def = medias_def;
    this.selectors_def = selectors_def;
    this.name = name2;
  }
};
function compute_property(indent2, key2, value4, important) {
  let base_indent = indent(indent2);
  let important_ = (() => {
    if (important) {
      return " !important";
    } else {
      return "";
    }
  })();
  return base_indent + key2 + ": " + value4 + important_ + ";";
}
function init_computed_properties(indent2) {
  return new ComputedProperties(
    toList([]),
    toList([]),
    toList([]),
    toList([]),
    indent2
  );
}
function handle_class_name(props, class_name) {
  let classes2 = prepend(class_name, props.classes);
  return props.withFields({ classes: classes2 });
}
function handle_property(props, style2) {
  if (!(style2 instanceof Property)) {
    throw makeError(
      "assignment_no_match",
      "sketch/internals/style",
      77,
      "handle_property",
      "Assignment pattern did not match",
      { value: style2 }
    );
  }
  let key2 = style2.key;
  let value4 = style2.value;
  let important = style2.important;
  let css_property = compute_property(props.indent, key2, value4, important);
  let properties = prepend(css_property, props.properties);
  return props.withFields({ properties });
}
function wrap_pseudo_selectors(id2, indent2, pseudo_selectors) {
  return map3(
    pseudo_selectors,
    (p) => {
      return wrap_class(
        id2,
        p.properties,
        indent2,
        new Some(p.pseudo_selector)
      );
    }
  );
}
function compute_classes(class_name, computed_properties) {
  let properties = computed_properties.properties;
  let medias = computed_properties.medias;
  let classes2 = computed_properties.classes;
  let pseudo_selectors = computed_properties.pseudo_selectors;
  let class_def = wrap_class(
    class_name,
    properties,
    0,
    new None()
  );
  let medias_def = map3(
    medias,
    (_use0) => {
      let query = _use0.query;
      let properties$1 = _use0.properties;
      let pseudo_selectors$1 = _use0.pseudo_selectors;
      let selectors_def2 = wrap_pseudo_selectors(
        class_name,
        2,
        pseudo_selectors$1
      );
      let _pipe = toList([
        query + " {",
        wrap_class(class_name, properties$1, 2, new None())
      ]);
      let _pipe$1 = ((_capture) => {
        return prepend2(toList([selectors_def2, toList(["}"])]), _capture);
      })(_pipe);
      let _pipe$2 = concat2(_pipe$1);
      return join2(_pipe$2, "\n");
    }
  );
  let selectors_def = wrap_pseudo_selectors(class_name, 0, pseudo_selectors);
  let name2 = trim2(join2(classes2, " ") + " " + class_name);
  return new ComputedClass(class_def, medias_def, selectors_def, name2);
}
function handle_media(props, style2) {
  if (!(style2 instanceof Media)) {
    throw makeError(
      "assignment_no_match",
      "sketch/internals/style",
      84,
      "handle_media",
      "Assignment pattern did not match",
      { value: style2 }
    );
  }
  let query = style2.query;
  let styles = style2.styles;
  let computed_props = compute_properties(styles, props.indent + 2);
  let _pipe = new MediaProperty(
    query,
    computed_props.properties,
    computed_props.pseudo_selectors
  );
  let _pipe$1 = ((_capture) => {
    return prepend2(props.medias, _capture);
  })(
    _pipe
  );
  return ((m) => {
    return props.withFields({ medias: m });
  })(_pipe$1);
}
function compute_properties(properties, indent2) {
  return fold_right(
    properties,
    init_computed_properties(indent2),
    (acc, prop) => {
      if (prop instanceof ClassName) {
        let class_name = prop.class_name;
        return handle_class_name(acc, class_name);
      } else if (prop instanceof Property) {
        return handle_property(acc, prop);
      } else if (prop instanceof Media) {
        return handle_media(acc, prop);
      } else {
        return handle_pseudo_selector(acc, prop);
      }
    }
  );
}
function handle_pseudo_selector(props, style2) {
  if (!(style2 instanceof PseudoSelector)) {
    throw makeError(
      "assignment_no_match",
      "sketch/internals/style",
      96,
      "handle_pseudo_selector",
      "Assignment pattern did not match",
      { value: style2 }
    );
  }
  let pseudo_selector = style2.pseudo_selector;
  let styles = style2.styles;
  let computed_props = compute_properties(styles, props.indent + 2);
  let _pipe = new PseudoProperty(pseudo_selector, computed_props.properties);
  let _pipe$1 = ((_capture) => {
    return prepend2(computed_props.pseudo_selectors, _capture);
  })(_pipe);
  let _pipe$2 = append2(_pipe$1, props.pseudo_selectors);
  return ((p) => {
    return props.withFields({ pseudo_selectors: p });
  })(_pipe$2);
}

// build/dev/javascript/sketch/sketch.ffi.mjs
function compileClass(styles, classId) {
  if (!cache) {
    warn.setup();
    return { name: "", className: "" };
  }
  const className = classId ?? getFunctionName();
  const content = cache.persist(className);
  if (content)
    return content;
  const id2 = uid(className);
  const computedProperties = compute_properties(styles, 2);
  const { name: name2, ...definitions2 } = compute_classes(
    id2,
    computedProperties
  );
  cache.store(className, {
    name: name2,
    definitions: definitions2,
    previousStyles: styles,
    indexRules: null
  });
  return { name: name2, className };
}
function toString({ name: name2 }) {
  return name2;
}

// build/dev/javascript/sketch/sketch/size.mjs
var Px = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Pt = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Vh = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Vw = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Em = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Rem = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Lh = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Rlh = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Pct = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
function px(value4) {
  return new Px(to_float(value4));
}
function percent(value4) {
  return new Pct(to_float(value4));
}
function to_string8(size) {
  if (size instanceof Px) {
    let value4 = size[0];
    return append4(to_string(value4), "px");
  } else if (size instanceof Pt) {
    let value4 = size[0];
    return append4(to_string(value4), "pt");
  } else if (size instanceof Pct) {
    let value4 = size[0];
    return append4(to_string(value4), "%");
  } else if (size instanceof Vh) {
    let value4 = size[0];
    return append4(to_string(value4), "vh");
  } else if (size instanceof Vw) {
    let value4 = size[0];
    return append4(to_string(value4), "vw");
  } else if (size instanceof Em) {
    let value4 = size[0];
    return append4(to_string(value4), "em");
  } else if (size instanceof Rem) {
    let value4 = size[0];
    return append4(to_string(value4), "rem");
  } else if (size instanceof Lh) {
    let value4 = size[0];
    return append4(to_string(value4), "lh");
  } else if (size instanceof Rlh) {
    let value4 = size[0];
    return append4(to_string(value4), "rlh");
  } else {
    let value4 = size[0];
    return append4(to_string(value4), "ch");
  }
}

// build/dev/javascript/sketch/sketch.mjs
var Style = class extends CustomType {
  constructor(internal) {
    super();
    this.internal = internal;
  }
};
function convert_styles(styles) {
  return map3(styles, (item) => {
    return item.internal;
  });
}
function property2(field2, content) {
  return new Style(new Property(field2, content, false));
}
function width(width2) {
  return property2("width", to_string8(width2));
}
function width_(width2) {
  return property2("width", width2);
}
function max_width_(width2) {
  return property2("max-width", width2);
}
function max_height_(height) {
  return property2("max-height", height);
}
function color(color2) {
  return property2("color", color2);
}
function font_family(font_family2) {
  return property2("font-family", font_family2);
}
function font_size(font_size2) {
  return property2("font-size", to_string8(font_size2));
}
function line_height(line_height2) {
  return property2("line-height", line_height2);
}
function white_space(white_space2) {
  return property2("white-space", white_space2);
}
function word_break(word_break2) {
  return property2("word-break", word_break2);
}
function display(display2) {
  return property2("display", display2);
}
function z_index(z_index2) {
  return property2("z-index", to_string3(z_index2));
}
function background(background2) {
  return property2("background", background2);
}
function position(position2) {
  return property2("position", position2);
}
function outline(outline2) {
  return property2("outline", outline2);
}
function gap(gap2) {
  return property2("gap", to_string8(gap2));
}
function grid_column(grid_column2) {
  return property2("grid-column", grid_column2);
}
function grid_template_columns(grid_template_columns2) {
  return property2("grid-template-columns", grid_template_columns2);
}
function align_items(align) {
  return property2("align-items", align);
}
function justify_content(justify) {
  return property2("justify-content", justify);
}
function justify_self(justify) {
  return property2("justify-self", justify);
}
function appearance(appearance2) {
  return property2("appearance", appearance2);
}
function top(size) {
  return property2("top", to_string8(size));
}
function bottom(size) {
  return property2("bottom", to_string8(size));
}
function right(size) {
  return property2("right", to_string8(size));
}
function left(size) {
  return property2("left", to_string8(size));
}
function box_shadow(box_shadow2) {
  return property2("box-shadow", box_shadow2);
}
function overflow(overflow2) {
  return property2("overflow", overflow2);
}
function overflow_y(overflow_y2) {
  return property2("overflow-y", overflow_y2);
}
function flex_direction(flex_direction2) {
  return property2("flex-direction", flex_direction2);
}
function border(border2) {
  return property2("border", border2);
}
function border_bottom(border_bottom2) {
  return property2("border-bottom", border_bottom2);
}
function border_right(border_right2) {
  return property2("border-right", border_right2);
}
function border_radius(border_radius2) {
  return property2("border-radius", to_string8(border_radius2));
}
function padding(padding2) {
  return property2("padding", to_string8(padding2));
}
function padding_(padding2) {
  return property2("padding", padding2);
}
function margin(margin2) {
  return property2("margin", to_string8(margin2));
}
function compose(class$3) {
  let _pipe = class$3;
  let _pipe$1 = toString(_pipe);
  let _pipe$2 = new ClassName(_pipe$1);
  return new Style(_pipe$2);
}
function class$2(styles) {
  let _pipe = styles;
  let _pipe$1 = convert_styles(_pipe);
  return compileClass(_pipe$1);
}
function dynamic(id2, styles) {
  let _pipe = styles;
  let _pipe$1 = convert_styles(_pipe);
  return compileClass(_pipe$1, id2);
}
function to_lustre(class$3) {
  let _pipe = class$3;
  let _pipe$1 = toString(_pipe);
  let _pipe$2 = split3(_pipe$1, " ");
  let _pipe$3 = map3(_pipe$2, (value4) => {
    return [value4, true];
  });
  return classes(_pipe$3);
}

// build/dev/javascript/sketch/sketch/lustre.mjs
function setup(options) {
  return createCache(options);
}
function compose2(view3, cache2) {
  return (model) => {
    prepareCache(cache2);
    let el2 = view3(model);
    let $ = renderCache(cache2);
    return el2;
  };
}

// build/dev/javascript/tardis/tardis/error.mjs
var SketchError = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var LustreError = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};

// build/dev/javascript/plinth/storage_ffi.mjs
function localStorage() {
  try {
    if (globalThis.Storage && globalThis.localStorage instanceof globalThis.Storage) {
      return new Ok2(globalThis.localStorage);
    } else {
      return new Error2(null);
    }
  } catch {
    return new Error2(null);
  }
}
function getItem(storage, keyName) {
  return null_or(storage.getItem(keyName));
}
function setItem(storage, keyName, keyValue) {
  try {
    storage.setItem(keyName, keyValue);
    return new Ok2(null);
  } catch {
    return new Error2(null);
  }
}
function null_or(val) {
  if (val !== null) {
    return new Ok2(val);
  } else {
    return new Error2(null);
  }
}

// build/dev/javascript/tardis/tardis/internals/data/colors.mjs
var Colors = class extends CustomType {
  constructor(background2, shadow2, primary, editor_fg, editor_bg, gutter, syntax_comment, button2, function$, nil, bool3, constant, bit_array, utf_codepoint, string3, number, custom_type, regex, date) {
    super();
    this.background = background2;
    this.shadow = shadow2;
    this.primary = primary;
    this.editor_fg = editor_fg;
    this.editor_bg = editor_bg;
    this.gutter = gutter;
    this.syntax_comment = syntax_comment;
    this.button = button2;
    this.function = function$;
    this.nil = nil;
    this.bool = bool3;
    this.constant = constant;
    this.bit_array = bit_array;
    this.utf_codepoint = utf_codepoint;
    this.string = string3;
    this.number = number;
    this.custom_type = custom_type;
    this.regex = regex;
    this.date = date;
  }
};
var AyuDark = class extends CustomType {
};
var AyuLight = class extends CustomType {
};
var CatpuccinLight = class extends CustomType {
};
var CatpuccinFrappe = class extends CustomType {
};
var Gleam = class extends CustomType {
};
function cs_to_string(color_scheme) {
  if (color_scheme instanceof AyuDark) {
    return "Ayu Dark";
  } else if (color_scheme instanceof AyuLight) {
    return "Ayu Light";
  } else if (color_scheme instanceof CatpuccinLight) {
    return "Catpuccin Light";
  } else if (color_scheme instanceof CatpuccinFrappe) {
    return "Catpuccin Frapp\xE9";
  } else {
    return "Gleam";
  }
}
function cs_from_string(key2) {
  if (key2 === "Ayu Dark") {
    return new AyuDark();
  } else if (key2 === "Ayu Light") {
    return new AyuLight();
  } else if (key2 === "Catpuccin Light") {
    return new CatpuccinLight();
  } else if (key2 === "Catpuccin Frapp\xE9") {
    return new CatpuccinFrappe();
  } else if (key2 === "Gleam") {
    return new Gleam();
  } else {
    return new Gleam();
  }
}
function themes() {
  return toList([
    new AyuDark(),
    new AyuLight(),
    new CatpuccinLight(),
    new CatpuccinFrappe(),
    new Gleam()
  ]);
}
var settings_key = "lustre-debugger-color";
function choose_color_scheme() {
  let _pipe = localStorage();
  let _pipe$1 = try$(
    _pipe,
    (_capture) => {
      return getItem(_capture, settings_key);
    }
  );
  let _pipe$2 = map2(_pipe$1, cs_from_string);
  return unwrap2(_pipe$2, new Gleam());
}
function save_color_scheme(color_scheme) {
  return from2(
    (_) => {
      let $ = try$(
        localStorage(),
        (local) => {
          let cs_s = cs_to_string(color_scheme);
          return setItem(local, settings_key, cs_s);
        }
      );
      return void 0;
    }
  );
}
var ayu_dark = new Colors(
  "#111",
  "#333",
  "#ffcc66",
  "#cccac2",
  "#242936",
  "#8a919966",
  "#b8cfe680",
  "#ffd173",
  "#ffd173",
  "#ffad66",
  "#dfbfff",
  "#ffad66",
  "#d5ff80",
  "#f28779",
  "#d5ff80",
  "#5ccfe6",
  "#73d0ff",
  "#95e6cb",
  "#dfbfff"
);
function ayu_dark_class() {
  let _pipe = class$2(
    toList([
      property2("--background", ayu_dark.background),
      property2("--shadow", ayu_dark.shadow),
      property2("--primary", ayu_dark.primary),
      property2("--editor-fg", ayu_dark.editor_fg),
      property2("--editor-bg", ayu_dark.editor_bg),
      property2("--gutter", ayu_dark.gutter),
      property2("--syntax-comment", ayu_dark.syntax_comment),
      property2("--button", ayu_dark.button),
      property2("--function", ayu_dark.function),
      property2("--nil", ayu_dark.nil),
      property2("--bool", ayu_dark.bool),
      property2("--constant", ayu_dark.constant),
      property2("--bit-array", ayu_dark.bit_array),
      property2("--utfcodepoint", ayu_dark.utf_codepoint),
      property2("--string", ayu_dark.string),
      property2("--number", ayu_dark.number),
      property2("--custom-type", ayu_dark.custom_type),
      property2("--regex", ayu_dark.regex),
      property2("--date", ayu_dark.date)
    ])
  );
  return to_lustre(_pipe);
}
var ayu_light = new Colors(
  "white",
  "#ccc",
  "#ffd596",
  "#5c6166",
  "#f8f9fa",
  "#8a919966",
  "#787b8099",
  "#F2AE49",
  "#F2AE49",
  "#fa8d3e",
  "#a37acc",
  "#fa8d3e",
  "#86b300",
  "#f07171",
  "#86b300",
  "#55b4d4",
  "#399ee6",
  "#4cbf43",
  "#a37acc"
);
function ayu_light_class() {
  let _pipe = class$2(
    toList([
      property2("--background", ayu_light.background),
      property2("--shadow", ayu_light.shadow),
      property2("--primary", ayu_light.primary),
      property2("--editor-fg", ayu_light.editor_fg),
      property2("--editor-bg", ayu_light.editor_bg),
      property2("--gutter", ayu_light.gutter),
      property2("--syntax-comment", ayu_light.syntax_comment),
      property2("--button", ayu_light.button),
      property2("--function", ayu_light.function),
      property2("--nil", ayu_light.nil),
      property2("--bool", ayu_light.bool),
      property2("--constant", ayu_light.constant),
      property2("--bit-array", ayu_light.bit_array),
      property2("--utfcodepoint", ayu_light.utf_codepoint),
      property2("--string", ayu_light.string),
      property2("--number", ayu_light.number),
      property2("--custom-type", ayu_light.custom_type),
      property2("--regex", ayu_light.regex),
      property2("--date", ayu_light.date)
    ])
  );
  return to_lustre(_pipe);
}
var catpuccin_light = new Colors(
  "#e6e9ef",
  "#dce0e8",
  "#dc8a78",
  "#4c4f69",
  "#eff1f5",
  "#dce0e8",
  "#6c6f85",
  "#dd7878",
  "#ea76cb",
  "#8839ef",
  "#d20f39",
  "#8839ef",
  "#40a02b",
  "#fe640b",
  "#40a02b",
  "#04a5e5",
  "#7287fd",
  "#179299",
  "#d20f39"
);
function catpuccin_light_class() {
  let _pipe = class$2(
    toList([
      property2("--background", catpuccin_light.background),
      property2("--shadow", catpuccin_light.shadow),
      property2("--primary", catpuccin_light.primary),
      property2("--editor-fg", catpuccin_light.editor_fg),
      property2("--editor-bg", catpuccin_light.editor_bg),
      property2("--gutter", catpuccin_light.gutter),
      property2("--syntax-comment", catpuccin_light.syntax_comment),
      property2("--button", catpuccin_light.button),
      property2("--function", catpuccin_light.function),
      property2("--nil", catpuccin_light.nil),
      property2("--bool", catpuccin_light.bool),
      property2("--constant", catpuccin_light.constant),
      property2("--bit-array", catpuccin_light.bit_array),
      property2("--utfcodepoint", catpuccin_light.utf_codepoint),
      property2("--string", catpuccin_light.string),
      property2("--number", catpuccin_light.number),
      property2("--custom-type", catpuccin_light.custom_type),
      property2("--regex", catpuccin_light.regex),
      property2("--date", catpuccin_light.date)
    ])
  );
  return to_lustre(_pipe);
}
var catpuccin_frappe = new Colors(
  "#292c3c",
  "#232634",
  "#f2d5cf",
  "#c6d0f5",
  "#303446",
  "#232634",
  "#a5adce",
  "#eebebe",
  "#f4b8e4",
  "#ca9ee6",
  "#e78284",
  "#ca9ee6",
  "#a6d189",
  "#ef9f76",
  "#a6d189",
  "#99d1db",
  "#babbf1",
  "#81c8be",
  "#e78284"
);
function catpuccin_frappe_class() {
  let _pipe = class$2(
    toList([
      property2("--background", catpuccin_frappe.background),
      property2("--shadow", catpuccin_frappe.shadow),
      property2("--primary", catpuccin_frappe.primary),
      property2("--editor-fg", catpuccin_frappe.editor_fg),
      property2("--editor-bg", catpuccin_frappe.editor_bg),
      property2("--gutter", catpuccin_frappe.gutter),
      property2("--syntax-comment", catpuccin_frappe.syntax_comment),
      property2("--button", catpuccin_frappe.button),
      property2("--function", catpuccin_frappe.function),
      property2("--nil", catpuccin_frappe.nil),
      property2("--bool", catpuccin_frappe.bool),
      property2("--constant", catpuccin_frappe.constant),
      property2("--bit-array", catpuccin_frappe.bit_array),
      property2("--utfcodepoint", catpuccin_frappe.utf_codepoint),
      property2("--string", catpuccin_frappe.string),
      property2("--number", catpuccin_frappe.number),
      property2("--custom-type", catpuccin_frappe.custom_type),
      property2("--regex", catpuccin_frappe.regex),
      property2("--date", catpuccin_frappe.date)
    ])
  );
  return to_lustre(_pipe);
}
var gleam = new Colors(
  "#2f2f2f",
  "#2f2f2f",
  "#ffaff3",
  "#fefefc",
  "#292d3e",
  "#8a919966",
  "#848484",
  "#ffaff3",
  "#ffd596",
  "#d4d4d4",
  "#ff6262",
  "#d4d4d4",
  "#c8ffa7",
  "#c8ffa7",
  "#c8ffa7",
  "#a6f0fc",
  "#9ce7ff",
  "#fdffab",
  "#ffddfa"
);
function gleam_class() {
  let _pipe = class$2(
    toList([
      property2("--background", gleam.background),
      property2("--shadow", gleam.shadow),
      property2("--primary", gleam.primary),
      property2("--editor-fg", gleam.editor_fg),
      property2("--editor-bg", gleam.editor_bg),
      property2("--gutter", gleam.gutter),
      property2("--syntax-comment", gleam.syntax_comment),
      property2("--button", gleam.button),
      property2("--function", gleam.function),
      property2("--nil", gleam.nil),
      property2("--bool", gleam.bool),
      property2("--constant", gleam.constant),
      property2("--bit-array", gleam.bit_array),
      property2("--utfcodepoint", gleam.utf_codepoint),
      property2("--string", gleam.string),
      property2("--number", gleam.number),
      property2("--custom-type", gleam.custom_type),
      property2("--regex", gleam.regex),
      property2("--date", gleam.date)
    ])
  );
  return to_lustre(_pipe);
}
function get_color_scheme_class(color_scheme) {
  if (color_scheme instanceof AyuLight) {
    return ayu_light_class();
  } else if (color_scheme instanceof AyuDark) {
    return ayu_dark_class();
  } else if (color_scheme instanceof CatpuccinLight) {
    return catpuccin_light_class();
  } else if (color_scheme instanceof CatpuccinFrappe) {
    return catpuccin_frappe_class();
  } else {
    return gleam_class();
  }
}

// build/dev/javascript/tardis/tardis/internals/data/step.mjs
var Step = class extends CustomType {
  constructor(index3, model, msg) {
    super();
    this.index = index3;
    this.model = model;
    this.msg = msg;
  }
};

// build/dev/javascript/tardis/tardis/internals/data/msg.mjs
var ToggleOpen = class extends CustomType {
};
var UpdateColorScheme = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Debug2 = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var SelectDebugger = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var AddApplication = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var AddStep = class extends CustomType {
  constructor(x0, x1, x2) {
    super();
    this[0] = x0;
    this[1] = x1;
    this[2] = x2;
  }
};
var BackToStep = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Restart = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};

// build/dev/javascript/tardis/tardis/internals/data/debugger.mjs
var Debugger = class extends CustomType {
  constructor(count, steps, dispatcher, selected_step) {
    super();
    this.count = count;
    this.steps = steps;
    this.dispatcher = dispatcher;
    this.selected_step = selected_step;
  }
};
function init4() {
  return new Debugger(1, toList([]), new None(), new None());
}
function add_dispatcher(debugger_, dispatcher) {
  return debugger_.withFields({ dispatcher: new Some(dispatcher) });
}
function replace3(debuggers, debugger_, mapper) {
  let _pipe = debuggers;
  let _pipe$1 = find2(
    _pipe,
    (item) => {
      return first(item) === debugger_;
    }
  );
  let _pipe$2 = unwrap2(_pipe$1, [debugger_, init4()]);
  let _pipe$3 = second(_pipe$2);
  let _pipe$4 = mapper(_pipe$3);
  return ((_capture) => {
    return key_set(debuggers, debugger_, _capture);
  })(
    _pipe$4
  );
}
function get2(debuggers, debugger_) {
  let _pipe = debuggers;
  let _pipe$1 = find2(
    _pipe,
    (item) => {
      return first(item) === debugger_;
    }
  );
  return map2(_pipe$1, second);
}
function unselect(debugger_) {
  return debugger_.withFields({ selected_step: new None() });
}
function select2(debugger_, step) {
  return debugger_.withFields({ selected_step: step });
}
function add_step(debugger_, model, msg) {
  let count = debugger_.count;
  let steps = debugger_.steps;
  let step = new Step(to_string3(count), model, msg);
  return debugger_.withFields({
    count: count + 1,
    steps: prepend(step, steps)
  });
}

// build/dev/javascript/tardis/tardis/internals/data/model.mjs
var Model = class extends CustomType {
  constructor(debuggers, color_scheme, frozen, opened, selected_debugger) {
    super();
    this.debuggers = debuggers;
    this.color_scheme = color_scheme;
    this.frozen = frozen;
    this.opened = opened;
    this.selected_debugger = selected_debugger;
  }
};
function optional_set_debugger(model, debugger_) {
  let selected2 = or(model.selected_debugger, new Some(debugger_));
  return model.withFields({ selected_debugger: selected2 });
}
function keep_active_debuggers(model) {
  return filter(
    model.debuggers,
    (debugger_) => {
      let steps = second(debugger_).steps;
      return !is_empty(steps);
    }
  );
}

// build/dev/javascript/plinth/document_ffi.mjs
function createElement(tagName) {
  return document.createElement(tagName);
}
function body() {
  return document.body;
}

// build/dev/javascript/tardis/tardis/internals/data.mjs
var DataNil = class extends CustomType {
};
var DataBool = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DataConstant = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DataBitArray = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DataUtfCodepoint = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DataString = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DataNumber = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DataTuple = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DataList = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DataCustomType = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var DataDict = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DataSet = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DataRegex = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DataDate = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DataFunction = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DataObject = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};

// build/dev/javascript/tardis/tardis.ffi.mjs
function inspect3(v) {
  const t = typeof v;
  if (v === true)
    return new DataBool("True");
  if (v === false)
    return new DataBool("False");
  if (v === null)
    return new DataConstant("//js(null)");
  if (v === void 0)
    return new DataNil();
  if (t === "string")
    return new DataString(JSON.stringify(v));
  if (t === "bigint" || t === "number")
    return new DataNumber(v.toString());
  if (Array.isArray(v))
    return new DataTuple(List.fromArray(v.map(inspect3)));
  if (v instanceof List)
    return inspectList2(v);
  if (v instanceof UtfCodepoint)
    return inspectUtfCodepoint2(v);
  if (v instanceof BitArray)
    return inspectBitArray2(v);
  if (v instanceof CustomType)
    return inspectCustomType2(v);
  if (v instanceof Dict)
    return inspectDict2(v);
  if (v instanceof Set)
    return DataSet(List.fromArray([...v].map(inspect3)));
  if (v instanceof RegExp)
    return new DataRegex(`//js(${v})`);
  if (v instanceof Date)
    return new DataDate(`//js(Date("${v.toISOString()}"))`);
  if (v instanceof Function) {
    const args = [];
    for (const i of Array(v.length).keys())
      args.push(String.fromCharCode(i + 97));
    return new DataFunction(`//fn(${args.join(", ")}) { ... }`);
  }
  return inspectObject2(v);
}
function inspectDict2(map8) {
  const data = [];
  map8.forEach((value4, key2) => data.push([inspect3(key2), inspect3(value4)]));
  return new DataDict(List.fromArray(data));
}
function inspectObject2(v) {
  const name2 = Object.getPrototypeOf(v)?.constructor?.name || "Object";
  const props = [];
  for (const k of Object.keys(v)) {
    props.push([inspect3(k), inspect3(v[k])]);
  }
  const head = name2 === "Object" ? "" : name2 + " ";
  return new DataObject(head, List.fromArray(props));
}
function inspectCustomType2(record) {
  const props = List.fromArray(
    Object.keys(record).map((label2) => {
      const value4 = inspect3(record[label2]);
      return isNaN(parseInt(label2)) ? [new Some(label2 + ": "), value4] : [new None(), value4];
    })
  );
  return new DataCustomType(record.constructor.name, props);
}
function inspectList2(list2) {
  return new DataList(List.fromArray(list2.toArray().map(inspect3)));
}
function inspectBitArray2(bits) {
  return new DataBitArray(`<<${Array.from(bits.buffer).join(", ")}>>`);
}
function inspectUtfCodepoint2(codepoint2) {
  return new DataUtfCodepoint(
    `//utfcodepoint(${String.fromCodePoint(codepoint2.value)})`
  );
}
function addCustomStyles(content) {
  const stylesheet2 = new CSSStyleSheet();
  stylesheet2.replace(content);
  document.adoptedStyleSheets.push(stylesheet2);
}
function updateLustre(application3, initMapper, updateMapper) {
  return application3.withFields({
    update: updateMapper(application3.update),
    init: initMapper(application3.init)
  });
}

// build/dev/javascript/tardis/tardis/internals/stylesheet.mjs
var stylesheet = "@font-face {\n  font-family: 'Lexend';\n  src: url(data:application/font-woff2;charset=utf-8;base64,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) format('woff2'),\n        url(data:application/font-woff;charset=utf-8;base64,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) format('woff');\n  font-weight: normal;\n  font-style: normal;\n}";

// build/dev/javascript/tardis/tardis/internals/setup.mjs
function instanciate_shadow_root(element2) {
  let div2 = createElement("div");
  let root2 = attachShadow(div2, new Open());
  appendChild(body(), div2);
  setAttribute(div2, "class", "tardis");
  appendChild2(root2, element2);
  return root2;
}
function instanciate_lustre_root() {
  let root2 = createElement("div");
  setAttribute(root2, "id", "tardis-start");
  return root2;
}
function mount_shadow_node() {
  addCustomStyles(stylesheet);
  let lustre_root_ = instanciate_lustre_root();
  let shadow_root = instanciate_shadow_root(lustre_root_);
  let lustre_root = unsafe_coerce(from(lustre_root_));
  return [shadow_root, lustre_root];
}
function wrap_init(middleware) {
  return (init7) => {
    return (flags) => {
      let new_state = init7(flags);
      let _pipe = new_state;
      let _pipe$1 = first(_pipe);
      let _pipe$2 = from(_pipe$1);
      middleware(_pipe$2, from("Init"));
      return new_state;
    };
  };
}
function wrap_update(middleware) {
  return (update4) => {
    return (model, msg) => {
      let new_state = update4(model, msg);
      let _pipe = new_state;
      let _pipe$1 = first(_pipe);
      let _pipe$2 = from(_pipe$1);
      middleware(_pipe$2, from(msg));
      return new_state;
    };
  };
}
function create_model_updater(dispatch2, application3) {
  return (dispatcher) => {
    let _pipe = (model) => {
      return from2(
        (_) => {
          let _pipe2 = model;
          let _pipe$12 = from(_pipe2);
          let _pipe$22 = new ForceModel(_pipe$12);
          let _pipe$3 = new Debug(_pipe$22);
          return unsafe_coerce(dispatcher)(_pipe$3);
        }
      );
    };
    let _pipe$1 = ((_capture) => {
      return new AddApplication(application3, _capture);
    })(_pipe);
    let _pipe$2 = dispatch(_pipe$1);
    return dispatch2(_pipe$2);
  };
}
function step_adder(dispatch2, name2) {
  return (model, msg) => {
    let _pipe = model;
    let _pipe$1 = ((_capture) => {
      return new AddStep(name2, _capture, msg);
    })(_pipe);
    let _pipe$2 = dispatch(_pipe$1);
    return dispatch2(_pipe$2);
  };
}

// build/dev/javascript/tardis/tardis/internals/styles.mjs
function panel_() {
  return class$2(
    toList([
      z_index(1000001),
      display("flex"),
      flex_direction("column"),
      position("fixed"),
      bottom(px(12)),
      right(px(12)),
      background("var(--background)"),
      border_radius(px(10)),
      box_shadow("0px 0px 5px 1px var(--shadow)"),
      overflow("hidden"),
      border("2px solid var(--primary)"),
      color("var(--editor-fg)"),
      width(px(1e3)),
      max_width_("calc(100vw - 24px)"),
      max_height_("min(1200px, calc(100vh - 24px))")
    ])
  );
}
function panel() {
  let _pipe = panel_();
  return to_lustre(_pipe);
}
function panel_closed() {
  let _pipe = toList([
    compose(panel_()),
    width(px(400)),
    justify_content("center")
  ]);
  let _pipe$1 = class$2(_pipe);
  return to_lustre(_pipe$1);
}
function grid_header_() {
  return class$2(
    toList([
      display("grid"),
      grid_column("1 / 4"),
      grid_template_columns("subgrid"),
      position("sticky"),
      top(px(0))
    ])
  );
}
function grid_header() {
  let _pipe = grid_header_();
  return to_lustre(_pipe);
}
function bordered_grid_header() {
  let _pipe = class$2(
    toList([
      compose(grid_header_()),
      border_bottom("2px solid var(--primary)")
    ])
  );
  return to_lustre(_pipe);
}
function header_() {
  return class$2(
    toList([
      background("var(--background)"),
      padding(px(12)),
      display("flex"),
      align_items("center"),
      justify_content("space-between"),
      font_family("Lexend")
    ])
  );
}
function header() {
  let _pipe = header_();
  return to_lustre(_pipe);
}
function bordered_header() {
  let _pipe = toList([compose(header_())]);
  let _pipe$1 = class$2(_pipe);
  return to_lustre(_pipe$1);
}
function body2() {
  let _pipe = class$2(
    toList([
      display("grid"),
      grid_template_columns("auto 2fr 3fr"),
      font_family("monospace"),
      overflow_y("auto"),
      width_("100%"),
      white_space("pre-wrap"),
      font_size(px(10))
    ])
  );
  return to_lustre(_pipe);
}
function details_() {
  return class$2(
    toList([
      display("grid"),
      grid_column("1 / 4"),
      grid_template_columns("subgrid"),
      background("var(--editor-bg)"),
      font_size(px(14)),
      border_bottom("1px solid var(--gutter)")
    ])
  );
}
function details() {
  let _pipe = details_();
  return to_lustre(_pipe);
}
function selected_details() {
  let _pipe = toList([
    compose(details_()),
    background("var(--shadow)")
  ]);
  let _pipe$1 = class$2(_pipe);
  return to_lustre(_pipe$1);
}
function step_index() {
  let _pipe = class$2(
    toList([
      padding_("9px 9px"),
      justify_self("end"),
      border_right("1px solid var(--gutter)"),
      font_family("Lexend"),
      color("var(--syntax-comment)")
    ])
  );
  return to_lustre(_pipe);
}
function step_msg() {
  let _pipe = class$2(
    toList([
      overflow("hidden"),
      word_break("break-all"),
      padding(px(9)),
      border_right("1px solid var(--gutter)")
    ])
  );
  return to_lustre(_pipe);
}
function step_model() {
  let _pipe = class$2(
    toList([
      overflow("hidden"),
      word_break("break-all"),
      padding(px(6))
    ])
  );
  return to_lustre(_pipe);
}
function actions_section() {
  let _pipe = class$2(
    toList([
      display("flex"),
      gap(px(12)),
      align_items("center"),
      white_space("nowrap")
    ])
  );
  return to_lustre(_pipe);
}
function toggle_button() {
  let _pipe = class$2(
    toList([
      appearance("none"),
      border("none"),
      background("none"),
      font_family("Lexend"),
      property2("cursor", "pointer"),
      color("var(--button)")
    ])
  );
  return to_lustre(_pipe);
}
function keyword_color() {
  let _pipe = toList([color("var(--bool)"), white_space("pre")]);
  let _pipe$1 = class$2(_pipe);
  return to_lustre(_pipe$1);
}
function flex() {
  let _pipe = toList([display("flex")]);
  let _pipe$1 = class$2(_pipe);
  return to_lustre(_pipe$1);
}
function debugger_title() {
  let _pipe = class$2(
    toList([
      display("flex"),
      align_items("center"),
      gap(px(18))
    ])
  );
  return to_lustre(_pipe);
}
function text_color(color2) {
  let _pipe = "syntax-" + color2;
  let _pipe$1 = dynamic(_pipe, toList([color(color2)]));
  return to_lustre(_pipe$1);
}
function subgrid_header() {
  let _pipe = class$2(
    toList([
      font_size(px(14)),
      font_family("Lexend"),
      background("var(--background)"),
      padding(px(9))
    ])
  );
  return to_lustre(_pipe);
}
function select_cs() {
  let _pipe = class$2(
    toList([
      appearance("none"),
      background("transparent"),
      padding(px(6)),
      margin(px(0)),
      width(percent(100)),
      font_size(px(12)),
      font_family("inherit"),
      line_height("inherit"),
      color("var(--primary)"),
      border("1px solid var(--primary)"),
      border_radius(px(5)),
      outline("none")
    ])
  );
  return to_lustre(_pipe);
}
function frozen_panel() {
  let _pipe = class$2(
    toList([
      position("fixed"),
      top(px(0)),
      bottom(px(0)),
      right(px(0)),
      left(px(0)),
      z_index(1e6)
    ])
  );
  return to_lustre(_pipe);
}

// build/dev/javascript/tardis/tardis/internals/view.mjs
function view_data_line(indent2, prefix, text3, color2) {
  let idt = repeat2(" ", indent2);
  let text_color2 = text_color(color2);
  let $ = length2(prefix);
  if ($ === 0) {
    return div(toList([text_color2]), toList([text2(idt + text3)]));
  } else {
    return div(
      toList([flex()]),
      toList([
        div(toList([keyword_color()]), toList([text2(idt + prefix)])),
        div(toList([text_color2]), toList([text2(text3)]))
      ])
    );
  }
}
function select_grid_header_class(opened, model) {
  let $ = model.count;
  if (!opened) {
    return grid_header();
  } else if (opened && $ === 1) {
    return grid_header();
  } else {
    return bordered_grid_header();
  }
}
function view_grid_header(opened, model) {
  return div(
    toList([select_grid_header_class(opened, model)]),
    toList([
      div(toList([subgrid_header()]), toList([text2("Step")])),
      div(toList([subgrid_header()]), toList([text2("Msg")])),
      div(toList([subgrid_header()]), toList([text2("Model")]))
    ])
  );
}
function count_data(data) {
  if (data instanceof DataNil) {
    return 1;
  } else if (data instanceof DataBool) {
    return 1;
  } else if (data instanceof DataConstant) {
    return 1;
  } else if (data instanceof DataBitArray) {
    return 1;
  } else if (data instanceof DataUtfCodepoint) {
    return 1;
  } else if (data instanceof DataString) {
    return 1;
  } else if (data instanceof DataNumber) {
    return 1;
  } else if (data instanceof DataRegex) {
    return 1;
  } else if (data instanceof DataDate) {
    return 1;
  } else if (data instanceof DataFunction) {
    return 1;
  } else if (data instanceof DataTuple) {
    let vs = data[0];
    let _pipe = map3(vs, count_data);
    return fold2(_pipe, 2, (acc, val) => {
      return acc + val;
    });
  } else if (data instanceof DataList) {
    let vs = data[0];
    let _pipe = map3(vs, count_data);
    return fold2(_pipe, 2, (acc, val) => {
      return acc + val;
    });
  } else if (data instanceof DataCustomType) {
    let vs = data[1];
    let _pipe = map3(vs, (d) => {
      return count_data(second(d));
    });
    return fold2(_pipe, 2, (acc, val) => {
      return acc + val;
    });
  } else if (data instanceof DataDict) {
    let vs = data[0];
    let _pipe = map3(vs, (d) => {
      return count_data(second(d));
    });
    return fold2(_pipe, 2, (acc, val) => {
      return acc + val;
    });
  } else if (data instanceof DataSet) {
    let vs = data[0];
    let _pipe = map3(vs, (d) => {
      return count_data(d);
    });
    return fold2(_pipe, 2, (acc, val) => {
      return acc + val;
    });
  } else {
    let vs = data[1];
    let _pipe = map3(vs, (d) => {
      return count_data(second(d));
    });
    return fold2(_pipe, 2, (acc, val) => {
      return acc + val;
    });
  }
}
function display_parenthesis(should_display, p) {
  if (should_display) {
    return p;
  } else {
    return "";
  }
}
function view_data_tuple(values2, p, i) {
  return concat2(
    toList([
      toList([view_data_line(i, p, "#(", "var(--editor-fg)")]),
      flat_map(
        values2,
        (_capture) => {
          return view_data(_capture, i + 2, "");
        }
      ),
      toList([view_data_line(i, p, ")", "var(--editor-fg)")])
    ])
  );
}
function view_data(data, i, p) {
  if (data instanceof DataNil) {
    return toList([view_data_line(i, p, "Nil", "var(--nil)")]);
  } else if (data instanceof DataBool) {
    let v = data[0];
    return toList([view_data_line(i, p, v, "var(--bool)")]);
  } else if (data instanceof DataConstant) {
    let v = data[0];
    return toList([view_data_line(i, p, v, "var(--constant)")]);
  } else if (data instanceof DataBitArray) {
    let v = data[0];
    return toList([view_data_line(i, p, v, "var(--bit-array)")]);
  } else if (data instanceof DataUtfCodepoint) {
    let v = data[0];
    return toList([view_data_line(i, p, v, "var(--utfcodepoint)")]);
  } else if (data instanceof DataString) {
    let v = data[0];
    return toList([view_data_line(i, p, v, "var(--string)")]);
  } else if (data instanceof DataNumber) {
    let v = data[0];
    return toList([view_data_line(i, p, v, "var(--number)")]);
  } else if (data instanceof DataRegex) {
    let v = data[0];
    return toList([view_data_line(i, p, v, "var(--regex)")]);
  } else if (data instanceof DataDate) {
    let v = data[0];
    return toList([view_data_line(i, p, v, "var(--date)")]);
  } else if (data instanceof DataFunction) {
    let v = data[0];
    return toList([view_data_line(i, p, v, "var(--function)")]);
  } else if (data instanceof DataTuple) {
    let vs = data[0];
    return view_data_tuple(vs, p, i);
  } else if (data instanceof DataList) {
    let vs = data[0];
    return view_data_list(vs, p, i);
  } else if (data instanceof DataCustomType) {
    let name2 = data[0];
    let vs = data[1];
    return view_data_custom_type(name2, vs, p, i);
  } else if (data instanceof DataDict) {
    let vs = data[0];
    return view_data_dict(vs, p, i);
  } else if (data instanceof DataSet) {
    let vs = data[0];
    return view_data_set(vs, p, i);
  } else {
    let name2 = data[0];
    let vs = data[1];
    return view_data_object(name2, vs, p, i);
  }
}
function view_step(debugger_, selected_step, item) {
  let index3 = item.index;
  let model = item.model;
  let msg = item.msg;
  let class$3 = (() => {
    let $ = unwrap(selected_step, "") === index3;
    if ($) {
      return selected_details();
    } else {
      return details();
    }
  })();
  return div(
    toList([class$3, on_click(new BackToStep(debugger_, item))]),
    toList([
      div(toList([step_index()]), toList([text2(index3)])),
      div(toList([step_msg()]), view_data(inspect3(msg), 0, "")),
      div(toList([step_model()]), view_data(inspect3(model), 0, ""))
    ])
  );
}
function view_model(opened, debugger_, model) {
  let selected2 = model.selected_step;
  if (!opened) {
    return none3();
  } else {
    return keyed(
      (_capture) => {
        return div(toList([body2()]), _capture);
      },
      (() => {
        let _pipe = model.steps;
        let _pipe$1 = take(_pipe, 100);
        let _pipe$2 = map3(
          _pipe$1,
          (i) => {
            return [i.index, view_step(debugger_, selected2, i)];
          }
        );
        return prepend2(
          _pipe$2,
          ["header", view_grid_header(opened, model)]
        );
      })()
    );
  }
}
function view_data_list(values2, p, i) {
  let open_list = view_data_line(i, p, "[", "var(--editor-fg)");
  let close_list = (idt) => {
    return view_data_line(idt, "", "]", "var(--editor-fg)");
  };
  let $ = is_empty(values2);
  if ($) {
    return toList([
      div(toList([flex()]), toList([open_list, close_list(0)]))
    ]);
  } else {
    return concat2(
      toList([
        toList([open_list]),
        flat_map(
          values2,
          (_capture) => {
            return view_data(_capture, i + 2, "");
          }
        ),
        toList([close_list(i)])
      ])
    );
  }
}
function view_data_custom_type(name2, values2, p, i) {
  let open_type = (display_paren) => {
    let paren = display_parenthesis(display_paren, "(");
    return view_data_line(i, p, name2 + paren, "var(--custom-type)");
  };
  let close_type = (idt, display_paren) => {
    let paren = display_parenthesis(display_paren, ")");
    return view_data_line(idt, "", paren, "var(--custom-type)");
  };
  let body_type = (inline) => {
    let $ = (() => {
      if (!inline) {
        return [0, 0];
      } else {
        return [i, i + 2];
      }
    })();
    let f = $[0];
    let e = $[1];
    return concat2(
      toList([
        toList([open_type(true)]),
        flat_map(
          values2,
          (data) => {
            let prefix = unwrap(first(data), "");
            return view_data(second(data), e, prefix);
          }
        ),
        toList([close_type(f, true)])
      ])
    );
  };
  if (values2.atLeastLength(2)) {
    return body_type(true);
  } else if (values2.atLeastLength(1)) {
    let v = fold2(
      values2,
      0,
      (acc, d) => {
        let $2 = acc > 2;
        if ($2) {
          return acc;
        } else {
          let data = count_data(second(d));
          return data + acc;
        }
      }
    );
    let $ = v > 2;
    if ($) {
      return body_type(true);
    } else {
      return toList([div(toList([flex()]), body_type(false))]);
    }
  } else {
    return toList([
      div(
        toList([flex()]),
        toList([open_type(false), close_type(0, false)])
      )
    ]);
  }
}
function view_data_dict(values2, p, i) {
  return concat2(
    toList([
      toList([view_data_line(i, p, "//js dict.from_list([", "var(--editor-fg)")]),
      flat_map(
        values2,
        (data) => {
          return toList([
            div(
              toList([flex()]),
              concat2(
                toList([
                  view_data(first(data), i + 2, "#("),
                  view_data(second(data), 0, ", "),
                  toList([
                    div(
                      toList([text_color("var(--bool)")]),
                      toList([text2(")")])
                    )
                  ]),
                  toList([text2(",")])
                ])
              )
            )
          ]);
        }
      ),
      toList([view_data_line(i, "", "])", "var(--editor-fg)")])
    ])
  );
}
function view_data_set(vs, p, i) {
  return concat2(
    toList([
      toList([view_data_line(i, p, "//js Set(", "var(--editor-fg)")]),
      flat_map(
        vs,
        (_capture) => {
          return view_data(_capture, i + 2, "");
        }
      ),
      toList([view_data_line(i, p, ")", "var(--editor-fg)")])
    ])
  );
}
function view_data_object(name2, vs, p, i) {
  return concat2(
    toList([
      toList([view_data_line(i, p, name2 + " {", "var(--editor-fg)")]),
      flat_map(
        vs,
        (data) => {
          return view_data(second(data), i + 2, "");
        }
      ),
      toList([view_data_line(i, p, "}", "var(--editor-fg)")])
    ])
  );
}

// build/dev/javascript/tardis/tardis.mjs
var Tardis = class extends CustomType {
  constructor(dispatch2) {
    super();
    this.dispatch = dispatch2;
  }
};
var Instance = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
function activate(result, instance) {
  return map2(
    result,
    (dispatch2) => {
      let dispatcher = instance[0][0];
      dispatcher(from(dispatch2));
      return dispatch2;
    }
  );
}
function start_lustre(lustre_root, application3) {
  let _pipe = application3;
  let _pipe$1 = start3(_pipe, lustre_root, void 0);
  return map_error(
    _pipe$1,
    (var0) => {
      return new LustreError(var0);
    }
  );
}
function start_sketch(root2) {
  let setup$1 = setup(shadow(root2));
  return map_error(
    setup$1,
    (error) => {
      debug("Unable to start sketch. Check your configuration.");
      debug(error);
      return new SketchError(error);
    }
  );
}
function init5(_) {
  let _pipe = choose_color_scheme();
  let _pipe$1 = ((_capture) => {
    return new Model(toList([]), _capture, false, false, new None());
  })(_pipe);
  return new$2(_pipe$1, none());
}
function update2(model, msg) {
  if (msg instanceof ToggleOpen) {
    return [model.withFields({ opened: !model.opened }), none()];
  } else if (msg instanceof Restart) {
    let debugger_ = msg[0];
    let restart_effect = (() => {
      let _pipe2 = model.debuggers;
      let _pipe$12 = filter_map(
        _pipe2,
        (d_) => {
          let d = second(d_);
          let fst_step = first2(d.steps);
          return try$(
            fst_step,
            (step) => {
              let _pipe$13 = d.dispatcher;
              let _pipe$22 = map(
                _pipe$13,
                (_capture) => {
                  return apply1(_capture, step.model);
                }
              );
              return to_result(_pipe$22, void 0);
            }
          );
        }
      );
      return batch(_pipe$12);
    })();
    let _pipe = model.debuggers;
    let _pipe$1 = replace3(_pipe, debugger_, unselect);
    let _pipe$2 = ((ds) => {
      return model.withFields({ frozen: false, debuggers: ds });
    })(_pipe$1);
    return new$2(_pipe$2, restart_effect);
  } else if (msg instanceof UpdateColorScheme) {
    let cs = msg[0];
    let _pipe = model.withFields({ color_scheme: cs });
    return new$2(_pipe, save_color_scheme(cs));
  } else if (msg instanceof AddApplication) {
    let debugger_ = msg[0];
    let dispatcher = msg[1];
    let _pipe = model.debuggers;
    let _pipe$1 = replace3(
      _pipe,
      debugger_,
      (_capture) => {
        return add_dispatcher(_capture, dispatcher);
      }
    );
    let _pipe$2 = ((d) => {
      return model.withFields({ debuggers: d });
    })(
      _pipe$1
    );
    return new$2(_pipe$2, none());
  } else if (msg instanceof BackToStep) {
    let debugger_ = msg[0];
    let item = msg[1];
    let selected_step = new Some(item.index);
    let model_effect = (() => {
      let _pipe2 = model.debuggers;
      let _pipe$12 = get2(_pipe2, debugger_);
      let _pipe$22 = try$(
        _pipe$12,
        (d) => {
          let _pipe$23 = d.dispatcher;
          let _pipe$3 = map(
            _pipe$23,
            (_capture) => {
              return apply1(_capture, item.model);
            }
          );
          return to_result(_pipe$3, void 0);
        }
      );
      return unwrap2(_pipe$22, none());
    })();
    let _pipe = model.debuggers;
    let _pipe$1 = replace3(
      _pipe,
      debugger_,
      (_capture) => {
        return select2(_capture, selected_step);
      }
    );
    let _pipe$2 = ((d) => {
      return model.withFields({ frozen: true, debuggers: d });
    })(_pipe$1);
    return new$2(_pipe$2, model_effect);
  } else if (msg instanceof Debug2) {
    let value4 = msg[0];
    debug(value4);
    return [model, none()];
  } else if (msg instanceof SelectDebugger) {
    let debugger_ = msg[0];
    let _pipe = model.withFields({
      selected_debugger: new Some(debugger_)
    });
    return new$2(_pipe, none());
  } else {
    let debugger_ = msg[0];
    let m = msg[1];
    let m_ = msg[2];
    let _pipe = model.debuggers;
    let _pipe$1 = replace3(
      _pipe,
      debugger_,
      (_capture) => {
        return add_step(_capture, m, m_);
      }
    );
    let _pipe$2 = ((d) => {
      return model.withFields({ debuggers: d });
    })(
      _pipe$1
    );
    let _pipe$3 = optional_set_debugger(_pipe$2, debugger_);
    return new$2(_pipe$3, none());
  }
}
function select_panel_options(panel_opened) {
  if (panel_opened) {
    return [panel(), bordered_header(), "Close"];
  } else {
    return [panel_closed(), header(), "Open"];
  }
}
function on_cs_input(content) {
  let cs = cs_from_string(content);
  return new UpdateColorScheme(cs);
}
function on_debugger_input(content) {
  return new SelectDebugger(content);
}
function color_scheme_selector(model) {
  let $ = model.opened;
  if (!$) {
    return none3();
  } else {
    return select(
      toList([on_input(on_cs_input), select_cs()]),
      map3(
        themes(),
        (item) => {
          let as_s = cs_to_string(item);
          let selected2 = isEqual(model.color_scheme, item);
          return option(
            toList([value(as_s), selected(selected2)]),
            as_s
          );
        }
      )
    );
  }
}
function restart_button(model) {
  let $ = model.frozen;
  let $1 = model.selected_debugger;
  if ($ && $1 instanceof Some) {
    let debugger_ = $1[0];
    return button(
      toList([select_cs(), on_click(new Restart(debugger_))]),
      toList([text2("Restart")])
    );
  } else {
    return none3();
  }
}
function view(model) {
  let color_scheme_class = get_color_scheme_class(model.color_scheme);
  let $ = select_panel_options(model.opened);
  let panel2 = $[0];
  let header2 = $[1];
  let button_txt = $[2];
  let frozen_panel2 = (() => {
    let $1 = model.frozen;
    if ($1) {
      return frozen_panel();
    } else {
      return none2();
    }
  })();
  let debugger_ = (() => {
    let _pipe = model.selected_debugger;
    let _pipe$1 = unwrap(_pipe, "");
    return ((_capture) => {
      return get2(model.debuggers, _capture);
    })(
      _pipe$1
    );
  })();
  return div(
    toList([class$("debugger_"), color_scheme_class, frozen_panel2]),
    toList([
      div(
        toList([panel2]),
        toList([
          div(
            toList([header2]),
            toList([
              div(
                toList([flex(), debugger_title()]),
                toList([
                  div(toList([]), toList([text2("Debugger")])),
                  color_scheme_selector(model),
                  restart_button(model)
                ])
              ),
              (() => {
                if (!debugger_.isOk()) {
                  return none3();
                } else {
                  let debugger_$1 = debugger_[0];
                  return div(
                    toList([actions_section()]),
                    toList([
                      select(
                        toList([
                          on_input(on_debugger_input),
                          select_cs()
                        ]),
                        map3(
                          keep_active_debuggers(model),
                          (_use0) => {
                            let item = _use0[0];
                            let selected2 = isEqual(
                              model.selected_debugger,
                              new Some(item)
                            );
                            return option(
                              toList([value(item), selected(selected2)]),
                              item
                            );
                          }
                        )
                      ),
                      div(
                        toList([]),
                        toList([
                          text2(
                            to_string3(debugger_$1.count - 1) + " Steps"
                          )
                        ])
                      ),
                      button(
                        toList([
                          toggle_button(),
                          on_click(new ToggleOpen())
                        ]),
                        toList([text2(button_txt)])
                      )
                    ])
                  );
                }
              })()
            ])
          ),
          (() => {
            let $1 = model.selected_debugger;
            if (debugger_.isOk() && $1 instanceof Some) {
              let debugger_$1 = debugger_[0];
              let d = $1[0];
              return view_model(model.opened, d, debugger_$1);
            } else {
              return none3();
            }
          })()
        ])
      )
    ])
  );
}
function setup2() {
  let $ = mount_shadow_node();
  let shadow_root = $[0];
  let lustre_root = $[1];
  let _pipe = start_sketch(shadow_root);
  let _pipe$1 = map2(
    _pipe,
    (_capture) => {
      return compose2(view, _capture);
    }
  );
  let _pipe$2 = map2(
    _pipe$1,
    (_capture) => {
      return application(init5, update2, _capture);
    }
  );
  let _pipe$3 = try$(
    _pipe$2,
    (_capture) => {
      return start_lustre(lustre_root, _capture);
    }
  );
  return map2(_pipe$3, (dispatch2) => {
    return new Tardis(dispatch2);
  });
}
function wrap(application3, instance) {
  let middleware = instance[0][1];
  return updateLustre(
    application3,
    wrap_init(middleware),
    wrap_update(middleware)
  );
}
function application2(instance, name2) {
  let dispatch2 = instance.dispatch;
  let updater = create_model_updater(dispatch2, name2);
  let adder = step_adder(dispatch2, name2);
  return new Instance([updater, adder]);
}
function single2(name2) {
  let _pipe = setup2();
  return map2(
    _pipe,
    (_capture) => {
      return application2(_capture, name2);
    }
  );
}

// build/dev/javascript/app/components/page_title.mjs
function page_title(title, styles) {
  return div(
    toList([
      class$(styles),
      class$(
        "mt-4 mb-2 sm:mb-4 mx-2 flex col-start-1 col-span-11 sm:col-start-1 sm:col-span-8 text-7xl"
      )
    ]),
    toList([
      h1(
        toList([
          id("title"),
          class$(
            "min-h-[56px] max-h-[140px] sm:max-h-[170px] overflow-hidden px-0 pb-1 w-full font-transitional font-bold italic text-ecru-white-950"
          )
        ]),
        toList([text(title)])
      )
    ])
  );
}

// build/dev/javascript/justin/justin.mjs
function add2(words, word) {
  if (word === "") {
    return words;
  } else {
    return prepend(word, words);
  }
}
function is_upper(g) {
  return lowercase2(g) !== g;
}
function split4(loop$in, loop$up, loop$word, loop$words) {
  while (true) {
    let in$ = loop$in;
    let up = loop$up;
    let word = loop$word;
    let words = loop$words;
    if (in$.hasLength(0) && word === "") {
      return reverse(words);
    } else if (in$.hasLength(0)) {
      return reverse(add2(words, word));
    } else if (in$.atLeastLength(1) && in$.head === "\n") {
      let in$1 = in$.tail;
      loop$in = in$1;
      loop$up = false;
      loop$word = "";
      loop$words = add2(words, word);
    } else if (in$.atLeastLength(1) && in$.head === "	") {
      let in$1 = in$.tail;
      loop$in = in$1;
      loop$up = false;
      loop$word = "";
      loop$words = add2(words, word);
    } else if (in$.atLeastLength(1) && in$.head === "!") {
      let in$1 = in$.tail;
      loop$in = in$1;
      loop$up = false;
      loop$word = "";
      loop$words = add2(words, word);
    } else if (in$.atLeastLength(1) && in$.head === "?") {
      let in$1 = in$.tail;
      loop$in = in$1;
      loop$up = false;
      loop$word = "";
      loop$words = add2(words, word);
    } else if (in$.atLeastLength(1) && in$.head === "#") {
      let in$1 = in$.tail;
      loop$in = in$1;
      loop$up = false;
      loop$word = "";
      loop$words = add2(words, word);
    } else if (in$.atLeastLength(1) && in$.head === ".") {
      let in$1 = in$.tail;
      loop$in = in$1;
      loop$up = false;
      loop$word = "";
      loop$words = add2(words, word);
    } else if (in$.atLeastLength(1) && in$.head === "-") {
      let in$1 = in$.tail;
      loop$in = in$1;
      loop$up = false;
      loop$word = "";
      loop$words = add2(words, word);
    } else if (in$.atLeastLength(1) && in$.head === "_") {
      let in$1 = in$.tail;
      loop$in = in$1;
      loop$up = false;
      loop$word = "";
      loop$words = add2(words, word);
    } else if (in$.atLeastLength(1) && in$.head === " ") {
      let in$1 = in$.tail;
      loop$in = in$1;
      loop$up = false;
      loop$word = "";
      loop$words = add2(words, word);
    } else {
      let g = in$.head;
      let in$1 = in$.tail;
      let $ = is_upper(g);
      if (!$) {
        loop$in = in$1;
        loop$up = false;
        loop$word = word + g;
        loop$words = words;
      } else if ($ && up) {
        loop$in = in$1;
        loop$up = up;
        loop$word = word + g;
        loop$words = words;
      } else {
        loop$in = in$1;
        loop$up = true;
        loop$word = g;
        loop$words = add2(words, word);
      }
    }
  }
}
function split_words(text3) {
  let _pipe = text3;
  let _pipe$1 = graphemes(_pipe);
  return split4(_pipe$1, false, "", toList([]));
}
function kebab_case(text3) {
  let _pipe = text3;
  let _pipe$1 = split_words(_pipe);
  let _pipe$2 = join2(_pipe$1, "-");
  return lowercase2(_pipe$2);
}

// node_modules/nanoid/url-alphabet/index.js
var urlAlphabet = "useandom-26T198340PX75pxJACKVERYMINDBUSHWOLF_GQZbfghjklqvwyzrict";

// node_modules/nanoid/index.browser.js
var nanoid = (size = 21) => {
  let id2 = "";
  let bytes = crypto.getRandomValues(new Uint8Array(size));
  while (size--) {
    id2 += urlAlphabet[bytes[size] & 63];
  }
  return id2;
};

// build/dev/javascript/app/seed.ts
var TagOptionSeed = [
  {
    name: "Cuisine",
    options: [
      "Mediterranean",
      "French",
      "Italian",
      "Chinese",
      "Thai",
      "Australian",
      "Japanese",
      "International"
    ]
  },
  {
    name: "Style",
    options: [
      "Veggie",
      "Meat & Sides",
      "Soups / Noodles / Stir Fry",
      "Salad",
      "Slow Cooker",
      "Oven Bake",
      "BBQ",
      "Bakery"
    ]
  },
  {
    name: "Label",
    options: [
      "Go-to",
      "Weeknight",
      "Fancy",
      "Light",
      "Substantial"
    ]
  }
];
var RecipeSeed = [{
  title: "Pink potato salad",
  slug: "pink-potato-salad",
  cook_time: 10,
  prep_time: 10,
  serves: 4,
  shortlisted: false,
  ingredients: /* @__PURE__ */ new Map([
    [0, { units: "g", quantity: "600", name: "Baby potato" }],
    [1, { units: "pc", quantity: "1 / 2", name: "Red Cabbage" }],
    [2, { units: "g", quantity: "200", name: "Pomegranate seeds" }],
    [3, { units: "tin", quantity: "1", name: "Butter Beans" }],
    [4, { units: "g", quantity: "100", name: "Mayonnaise" }],
    [5, { units: "g", quantity: "50", name: "Yoghurt" }],
    [6, { units: "tbsp", quantity: "3", name: "Extra Virgin Olive Oil" }],
    [7, { units: "pc", quantity: "1 / 2", name: "Lemon juice" }],
    [8, { units: "g", quantity: "15", name: "Flat - leaf parsley" }]
  ]),
  method_steps: [{
    step_text: "Boil the potatoes in salted water for 10 minutes, until they are just cooked through, then drain and rinse under running cold water to cool."
  }, {
    step_text: "While the potatoes are cooking, shred the cabbage, deseed the pomegranate (or open the packet), and drain and rinse the beans."
  }, {
    step_text: "In a bowl, mix the mayonnaise, yoghurt, lemon juice, oil, a teaspoon of flaky sea salt and plenty of pepper, then taste and adjust the seasoning accordingly."
  }, {
    step_text: "Put the cooled, drained potatoes, red cabbage, pomegranate, beans and the dressing in a large bowl, then taste and adjust the seasoning if necessary. Arrange on a large plate, scatter over the parsley and serve at room temperature."
  }],
  tags: [{ name: "Cuisine", value: "Australian" }, {
    name: "Style",
    value: "Salad"
  }, { name: "Label", value: "Light" }]
}];
async function seedDb() {
  console.log("beginning seedDb");
  const preparetables = await prepareTables();
  const tagoptions = await listTagOptions();
  console.log(tagoptions[0]);
  const recipes = await listRecipes();
  console.log(recipes[0]);
  console.log("tagoptions.length: ", tagoptions[0].length);
  if (tagoptions[0].length === 0) {
    for (const item of TagOptionSeed) {
      const res = await addTagOption(item);
    }
  }
  console.log("recipes.length: ", recipes.length);
  if (recipes.length === 0) {
    for (const item of RecipeSeed) {
      await addOrUpdateRecipe(item);
    }
  }
  console.log("finishing seedDb");
}

// build/dev/javascript/app/db.ts
var sqliteWasm = await import("https://esm.sh/@vlcn.io/crsqlite-wasm@0.16.0");
var sqlite = await sqliteWasm.default(
  () => "https://esm.sh/@vlcn.io/crsqlite-wasm@0.16.0/dist/crsqlite.wasm"
);
var db = await sqlite.open("mealstack.db");
function replacer(key2, value4) {
  if (value4 instanceof Map) {
    return {
      dataType: "Map",
      value: Array.from(value4.entries())
      // or with spread: value: [...value]
    };
  }
  return value4;
}
function reviver(key2, value4) {
  if (typeof value4 === "object" && value4 !== null) {
    if (value4.dataType === "Map") {
      return new Map(value4.value);
    }
  }
  return value4;
}
async function prepareTables() {
  const findTagOptionsTable = await db.execA(
    "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE `type`='table' AND `name`='tag_options')"
  );
  const tagOptionsTableExists = findTagOptionsTable[0][0];
  console.log(tagOptionsTableExists);
  if (!tagOptionsTableExists) {
    console.log("creating tag_options table...");
    await db.execA(
      "CREATE TABLE `tag_options` ( 			`id` text PRIMARY KEY NOT NULL, 			`name` text NOT NULL, 			`options` text NOT NULL 		)"
    );
  }
  const findRecipesTable = await db.execA(
    "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE `type`='table' AND `name`='recipes')"
  );
  const recipesTableExists = findRecipesTable[0][0];
  console.log(recipesTableExists);
  if (!recipesTableExists) {
    console.log("creating recipes table...");
    await db.execA(
      "CREATE TABLE `recipes` ( 			`id` text PRIMARY KEY NOT NULL, 			`slug` text, 			`title` text, 			`cook_time` integer, 			`prep_time` integer, 			`serves` integer, 			`ingredients` text, 			`method_steps` text, 			`tags` text, 			`shortlisted` integer 		)"
    );
  }
}
async function listTagOptions() {
  console.log("listTagOptions");
  const findRows = await db.execA("SELECT EXISTS(SELECT 1 FROM tag_options)");
  const exists = findRows[0][0];
  if (!exists) {
    return new Ok2([]);
  }
  const result = await db.execA("SELECT * FROM tag_options");
  return result ? new Ok2(result) : new Error2(void 0);
}
async function addTagOption(tagOption) {
  console.log("addTagOption: ", tagOption);
  const result = await db.execA(
    `INSERT INTO tag_options (id, name, options) VALUES (
			'${nanoid()}'
			,'${tagOption.name}'
			,'${JSON.stringify(tagOption.options)}'
		)`
  );
  console.log(result);
  return result ? new Ok2(result) : new Error2(void 0);
}
async function listRecipes() {
  console.log("listRecipes");
  const findRows = await db.execO("SELECT EXISTS(SELECT 1 FROM recipes)");
  const exists = findRows[0];
  if (!exists) {
    return new Ok2([]);
  }
  const result = await db.execO("SELECT id, title, slug, prep_time, cook_time, serves, tags, ingredients, method_steps FROM recipes");
  const mapped = result.map((recipe) => {
    recipe.tags = JSON.parse(recipe.tags);
    recipe.ingredients = JSON.parse(recipe.ingredients, reviver);
    recipe.method_steps = JSON.parse(recipe.method_steps);
    return recipe;
  });
  console.log("mapped: ", mapped);
  return mapped;
}
async function addOrUpdateRecipe(recipe) {
  console.log("addOrUpdateRecipe: ", recipe);
  const query = ` 		INSERT INTO recipes 		(id, slug, title, cook_time, prep_time, serves, ingredients, method_steps, tags, shortlisted) 		 VALUES ('${recipe.id ? recipe.id : nanoid()}', '${recipe.slug}', '${recipe.title}', '${recipe.cook_time}',
			'${recipe.prep_time}', '${recipe.serves}', '${JSON.stringify(recipe.ingredients, replacer)}',
			'${JSON.stringify(recipe.method_steps)}', '${JSON.stringify(recipe.tags)}', '${recipe.shortlisted}') 		 ON CONFLICT(id) DO UPDATE SET		 slug=excluded.slug, 		 title=excluded.title, 		 cook_time=excluded.cook_time, 		 prep_time=excluded.prep_time, 		 serves=excluded.serves, 		 ingredients=excluded.ingredients, 		 method_steps=excluded.method_steps, 		 tags=excluded.tags, 		 shortlisted=excluded.shortlisted;`;
  console.log("query: ", query);
  const result = await db.execA(
    query
  );
  return new Ok2();
}
async function do_get_recipes() {
  const _seed = await seedDb();
  const result = await listRecipes();
  console.log("result from ffi: ", result);
  return result;
}

// build/dev/javascript/app/lib/utils.mjs
function dict_update(dict2, key2, fun) {
  let item = (() => {
    let _pipe = dict2;
    let _pipe$1 = get(_pipe, key2);
    return from_result(_pipe$1);
  })();
  if (item instanceof Some) {
    let item$1 = item[0];
    let _pipe = item$1;
    let _pipe$1 = fun(_pipe);
    return ((_capture) => {
      return insert(dict2, key2, _capture);
    })(
      _pipe$1
    );
  } else {
    return dict2;
  }
}

// build/dev/javascript/app/pages/recipe.mjs
var UserUpdatedRecipeTitle = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UserUpdatedRecipePrepTimeHrs = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UserUpdatedRecipePrepTimeMins = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UserUpdatedRecipeCookTimeHrs = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UserUpdatedRecipeCookTimeMins = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UserUpdatedRecipeServes = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UserUpdatedIngredientNameAtIndex = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var UserSavedUpdatedRecipe = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DbSavedUpdatedRecipe = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var DbRetrievedRecipes = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var JSRecipe = class extends CustomType {
  constructor(id2, title, slug, cook_time, prep_time, serves, tags, ingredients, method_steps) {
    super();
    this.id = id2;
    this.title = title;
    this.slug = slug;
    this.cook_time = cook_time;
    this.prep_time = prep_time;
    this.serves = serves;
    this.tags = tags;
    this.ingredients = ingredients;
    this.method_steps = method_steps;
  }
};
var Recipe = class extends CustomType {
  constructor(id2, title, slug, cook_time, prep_time, serves, tags, ingredients, method_steps) {
    super();
    this.id = id2;
    this.title = title;
    this.slug = slug;
    this.cook_time = cook_time;
    this.prep_time = prep_time;
    this.serves = serves;
    this.tags = tags;
    this.ingredients = ingredients;
    this.method_steps = method_steps;
  }
};
var MethodStep = class extends CustomType {
  constructor(step_text) {
    super();
    this.step_text = step_text;
  }
};
var Tag = class extends CustomType {
  constructor(name2, value4) {
    super();
    this.name = name2;
    this.value = value4;
  }
};
var Ingredient = class extends CustomType {
  constructor(name2, ismain, quantity, units) {
    super();
    this.name = name2;
    this.ismain = ismain;
    this.quantity = quantity;
    this.units = units;
  }
};
function list_update(model, msg) {
  let recipes = msg[0];
  return [recipes, none()];
}
function view_recipe_summary(recipe) {
  return div(
    toList([
      class$(
        "col-span-full flex flex-wrap items-baseline justify-start my-1 text-base"
      )
    ]),
    toList([
      div(
        toList([
          class$("text-xl flex flex-nowrap gap-1 my-1 ml-2 items-baseline")
        ]),
        toList([
          a(
            toList([href(append4("/recipes/", recipe.slug))]),
            toList([
              span(toList([]), toList([text(recipe.title)])),
              span(
                toList([class$("text-sm")]),
                toList([
                  text(" \u2022 "),
                  text(
                    (() => {
                      let _pipe = floor_divide(
                        recipe.prep_time + recipe.cook_time,
                        60
                      );
                      let _pipe$1 = unwrap2(_pipe, 0);
                      return to_string3(_pipe$1);
                    })()
                  ),
                  text("h"),
                  text(
                    (() => {
                      let _pipe = remainderInt(
                        recipe.prep_time + recipe.cook_time,
                        60
                      );
                      return to_string3(_pipe);
                    })()
                  ),
                  text("m")
                ])
              )
            ])
          )
        ])
      )
    ])
  );
}
function view_recipe_list(model) {
  return section(
    toList([
      class$(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[fit-content(100px)_fit-content(100px)_1fr]"
      )
    ]),
    toList([
      page_title("Recipe Book", "underline-green"),
      nav(
        toList([
          class$(
            "flex flex-col justify-start items-middle col-span-1 col-start-12 text-base md:text-lg mt-4"
          )
        ]),
        toList([
          a(toList([href("/"), class$("text-center")]), toList([text("\u{1F3E0}")]))
        ])
      ),
      div(toList([class$("contents")]), map3(model, view_recipe_summary))
    ])
  );
}
function ingredient_input(ingredient, index3) {
  let with_index = curry2(
    (var0, var1) => {
      return new UserUpdatedIngredientNameAtIndex(var0, var1);
    }
  );
  return div(
    toList([class$("my-0.5 w-full flex justify-between items-baseline")]),
    toList([
      input(
        toList([
          attribute("aria-label", "Enter ingredient name"),
          name("ingredient-name-" + to_string3(index3)),
          type_("text"),
          placeholder("Ingredient"),
          class$(
            "pt-0.5 w-[16ch] xxs:w-[23ch] xs:w-[28ch] sm:w-[16ch] md:w-[23ch] lg:w-[28ch] text-base input-base input-focus bg-ecru-white-100"
          ),
          value(
            (() => {
              if (ingredient instanceof Some) {
                let ing = ingredient[0];
                return unwrap(ing.name, "");
              } else {
                return "";
              }
            })()
          ),
          on_input(with_index(index3))
        ])
      ),
      div(
        toList([class$("flex justify-end gap-1 items-baseline")]),
        toList([
          input(
            toList([
              attribute("aria-label", "Enter ingredient quanitity"),
              name("ingredient-qty-" + to_string3(index3)),
              type_("text"),
              placeholder("Qty"),
              class$("pt-0.5 w-[4ch] text-sm input-focus bg-ecru-white-100"),
              value(
                (() => {
                  if (ingredient instanceof Some) {
                    let ing = ingredient[0];
                    return unwrap(ing.quantity, "");
                  } else {
                    return "";
                  }
                })()
              )
            ])
          ),
          input(
            toList([
              attribute("aria-label", "Enter ingredient units"),
              name("ingredient-units-" + to_string3(index3)),
              type_("text"),
              placeholder("Units"),
              class$(
                "pt-0.5 w-[5ch] text-sm mr-0 input-focus bg-ecru-white-100"
              ),
              value(
                (() => {
                  if (ingredient instanceof Some) {
                    let ing = ingredient[0];
                    return unwrap(ing.units, "");
                  } else {
                    return "";
                  }
                })()
              )
            ])
          ),
          div(
            toList([class$("flex text-xs items-baseline")]),
            toList([
              label(
                toList([
                  class$("ingredient-toggle"),
                  attribute("aria-label", "Toggle main ingredient")
                ]),
                toList([
                  input(
                    toList([
                      checked(
                        (() => {
                          if (ingredient instanceof Some) {
                            let ing = ingredient[0];
                            return unwrap(ing.ismain, false);
                          } else {
                            return false;
                          }
                        })()
                      ),
                      name("`ingredient-main-" + to_string3(index3)),
                      type_("checkbox")
                    ])
                  ),
                  span(toList([]), toList([]))
                ])
              ),
              button(
                toList([
                  class$("text-ecru-white-950"),
                  type_("button"),
                  id("remove-ingredient-input")
                ]),
                toList([text("\u2796")])
              ),
              button(
                toList([
                  class$("text-ecru-white-950"),
                  type_("button"),
                  id("add-ingredient-input")
                ]),
                toList([text("\u2795")])
              )
            ])
          )
        ])
      )
    ])
  );
}
function method_step_input(method_step, index3) {
  return div(
    toList([class$("flex w-full items-baseline col-span-full px-1 mb-1")]),
    toList([
      label(
        toList([class$("font-mono")]),
        toList([
          text(
            (() => {
              let _pipe = index3 + 1;
              return to_string3(_pipe);
            })()
          )
        ])
      ),
      textarea(
        toList([
          name(
            "method-step-" + (() => {
              let _pipe = index3;
              return to_string3(_pipe);
            })()
          ),
          id(
            "method-step-" + (() => {
              let _pipe = index3;
              return to_string3(_pipe);
            })()
          ),
          class$(
            "px-2 py-1 bg-ecru-white-100 w-full input-focus text-base resize-none"
          )
        ]),
        (() => {
          if (method_step instanceof Some) {
            let a$1 = method_step[0];
            return a$1.step_text;
          } else {
            return "";
          }
        })()
      ),
      button(
        toList([
          class$("text-ecru-white-950"),
          type_("button"),
          id("remove-ingredient-input")
        ]),
        toList([text("\u2796")])
      ),
      button(
        toList([
          class$("text-ecru-white-950"),
          type_("button"),
          id("add-ingredient-input")
        ]),
        toList([text("\u2795")])
      )
    ])
  );
}
function edit_recipe_detail(recipe) {
  return form(
    toList([
      class$(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[fit-content(100px)_fit-content(100px)_1fr]"
      ),
      id("create_recipe_form"),
      on_submit(new UserSavedUpdatedRecipe(recipe))
    ]),
    toList([
      div(
        toList([
          class$(
            "mt-4 mb-2 sm:mb-4 mr-2 flex col-start-1 col-span-11 sm:col-start-1 sm:col-span-8"
          )
        ]),
        toList([
          textarea(
            toList([
              id("title"),
              name("title"),
              class$(
                "placeholder:underline-blue underline-blue min-h-[56px] max-h-[140px] sm:max-h-[170px] overflow-x-hidden px-0 pb-1 input-base w-full input-focus font-transitional resize-none font-bold italic text-ecru-white-950  text-7xl bg-ecru-white-100"
              ),
              attribute("title", "recipe title"),
              on_input((var0) => {
                return new UserUpdatedRecipeTitle(var0);
              })
            ]),
            recipe.title
          )
        ])
      ),
      fieldset(
        toList([
          class$(
            "mx-2 sm:mx-0 mt-0 sm:mt-4 flex sm:flex-wrap justify-between row-start-2 col-span-full sm:row-start-1 sm:col-span-3 sm:col-start-9"
          )
        ]),
        toList([
          fieldset(
            toList([class$("flex flex-wrap items-baseline mb-2")]),
            toList([
              label(
                toList([
                  class$("justify-self-start font-mono italic"),
                  for$("prep_time")
                ]),
                toList([text("Prep:")])
              ),
              div(
                toList([class$("justify-self-start")]),
                toList([
                  div(
                    toList([
                      class$("after:content-['h'] after:text-xs inline-block")
                    ]),
                    toList([
                      input(
                        toList([
                          id("prep_time_hrs"),
                          class$(
                            "bg-ecru-white-100 input-base input-focus pr-0.5 w-[3ch] text-right text-base"
                          ),
                          type_("number"),
                          name("prep_time_hrs"),
                          attribute("title", "prep time in hours"),
                          value(
                            (() => {
                              let _pipe = floor_divide(
                                recipe.prep_time,
                                60
                              );
                              let _pipe$1 = unwrap2(_pipe, 0);
                              let _pipe$2 = to_string3(_pipe$1);
                              return replace(_pipe$2, "0", "");
                            })()
                          ),
                          on_input(
                            (var0) => {
                              return new UserUpdatedRecipePrepTimeHrs(var0);
                            }
                          )
                        ])
                      )
                    ])
                  ),
                  div(
                    toList([
                      class$("after:content-['m'] after:text-xs inline-block")
                    ]),
                    toList([
                      input(
                        toList([
                          id("prep_time_mins"),
                          class$(
                            "bg-ecru-white-100 input-base input-focus pr-0.5 w-[3ch] text-right text-base"
                          ),
                          type_("number"),
                          name("prep_time_mins"),
                          attribute("title", "prep time in minutes"),
                          value(
                            (() => {
                              let _pipe = remainderInt(recipe.prep_time, 60);
                              return to_string3(_pipe);
                            })()
                          ),
                          on_input(
                            (var0) => {
                              return new UserUpdatedRecipePrepTimeMins(var0);
                            }
                          )
                        ])
                      )
                    ])
                  )
                ])
              )
            ])
          ),
          fieldset(
            toList([class$("flex flex-wrap items-baseline mb-2")]),
            toList([
              label(
                toList([
                  class$("justify-self-start font-mono italic"),
                  for$("prep_time")
                ]),
                toList([text("Cook:")])
              ),
              div(
                toList([class$("justify-self-start")]),
                toList([
                  div(
                    toList([
                      class$("after:content-['h'] after:text-xs inline-block")
                    ]),
                    toList([
                      input(
                        toList([
                          id("cook_time_hrs"),
                          class$(
                            "bg-ecru-white-100 input-base input-focus pr-0.5 w-[3ch] text-right text-base"
                          ),
                          type_("number"),
                          name("cook_time_hrs"),
                          attribute("title", "cook time in hours"),
                          value(
                            (() => {
                              let _pipe = floor_divide(
                                recipe.cook_time,
                                60
                              );
                              let _pipe$1 = unwrap2(_pipe, 0);
                              let _pipe$2 = to_string3(_pipe$1);
                              return replace(_pipe$2, "0", "");
                            })()
                          ),
                          on_input(
                            (var0) => {
                              return new UserUpdatedRecipeCookTimeHrs(var0);
                            }
                          )
                        ])
                      )
                    ])
                  ),
                  div(
                    toList([
                      class$("after:content-['m'] after:text-xs inline-block")
                    ]),
                    toList([
                      input(
                        toList([
                          id("cook_time_mins"),
                          class$(
                            "bg-ecru-white-100 input-base input-focus pr-0.5 w-[3ch] text-right text-base"
                          ),
                          type_("number"),
                          name("cook_time_mins"),
                          attribute("title", "cook time in minutes"),
                          value(
                            (() => {
                              let _pipe = remainderInt(recipe.cook_time, 60);
                              return to_string3(_pipe);
                            })()
                          ),
                          on_input(
                            (var0) => {
                              return new UserUpdatedRecipeCookTimeMins(var0);
                            }
                          )
                        ])
                      )
                    ])
                  )
                ])
              )
            ])
          ),
          fieldset(
            toList([class$("flex flex-wrap items-baseline mb-2")]),
            toList([
              label(
                toList([
                  class$("justify-self-start font-mono italic"),
                  for$("serves")
                ]),
                toList([text("Serves:")])
              ),
              input(
                toList([
                  id("serves"),
                  class$(
                    "bg-ecru-white-100 justify-self-start col-span-3 input-base input-focus pr-0.5 w-[3ch] text-right text-base"
                  ),
                  type_("number"),
                  name("serves"),
                  value(
                    (() => {
                      let _pipe = recipe.serves;
                      return to_string3(_pipe);
                    })()
                  ),
                  on_input(
                    (var0) => {
                      return new UserUpdatedRecipeServes(var0);
                    }
                  )
                ])
              )
            ])
          )
        ])
      ),
      nav(
        toList([
          class$(
            "flex flex-col justify-start items-middle col-span-1 col-start-12 text-sm sm:text-base md:text-lg my-4 text-center"
          )
        ]),
        toList([
          a(toList([href("/"), class$("text-center")]), toList([text("\u{1F3E0}")])),
          a(
            toList([href("/recipes/" + recipe.slug), class$("text-center")]),
            toList([text("\u274E")])
          ),
          button(toList([type_("submit"), class$("")]), toList([text("\u{1F4BE}")]))
        ])
      ),
      fieldset(
        toList([
          class$(
            "col-span-full my-1 mb-6 pt-1 pb-2 px-1 mr-1 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-6 [box-shadow:1px_1px_0_#9edef1]"
          )
        ]),
        toList([
          legend(
            toList([class$("mx-2 px-1 font-mono italic")]),
            toList([text("Ingredients")])
          ),
          (() => {
            let _pipe = recipe.ingredients;
            let _pipe$1 = map(
              _pipe,
              (_capture) => {
                return map_values(
                  _capture,
                  (i, item) => {
                    return ingredient_input(new Some(item), i);
                  }
                );
              }
            );
            let _pipe$2 = map(_pipe$1, values);
            let _pipe$3 = map(_pipe$2, fragment);
            return unwrap(_pipe$3, none3());
          })()
        ])
      ),
      fieldset(
        toList([
          class$(
            "col-span-full my-1 mb-6 pt-1 pb-2 px-1 mr-1 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-6 [box-shadow:1px_1px_0_#9edef1]"
          )
        ]),
        toList([
          legend(
            toList([class$("mx-2 px-1 font-mono italic")]),
            toList([text("Method")])
          ),
          (() => {
            let _pipe = recipe.method_steps;
            let _pipe$1 = map(
              _pipe,
              (_capture) => {
                return map3(
                  _capture,
                  (_capture2) => {
                    return new Some(_capture2);
                  }
                );
              }
            );
            let _pipe$2 = map(
              _pipe$1,
              (_capture) => {
                return index_map(_capture, method_step_input);
              }
            );
            let _pipe$3 = map(_pipe$2, fragment);
            return unwrap(_pipe$3, none3());
          })()
        ])
      )
    ])
  );
}
function lookup_and_edit_recipe(maybe_recipe) {
  if (maybe_recipe instanceof Some) {
    let a$1 = maybe_recipe[0];
    return edit_recipe_detail(a$1);
  } else {
    return page_title("Recipe not found", "");
  }
}
function view_ingredient(ingredient) {
  return div(
    toList([class$("flex justify-start col-span-6 text-sm items-baseline")]),
    toList([
      div(
        toList([class$("flex-grow-[2] text-left flex justify-start")]),
        toList([
          unwrap(
            map(
              ingredient.name,
              (_capture) => {
                return text(_capture);
              }
            ),
            none3()
          )
        ])
      ),
      div(
        toList([class$("col-span-1 text-xs")]),
        toList([
          unwrap(
            map(
              ingredient.quantity,
              (_capture) => {
                return text(_capture);
              }
            ),
            none3()
          )
        ])
      ),
      div(
        toList([class$("col-span-1 text-xs")]),
        toList([
          unwrap(
            map(
              ingredient.units,
              (_capture) => {
                return text(_capture);
              }
            ),
            none3()
          )
        ])
      )
    ])
  );
}
function view_method_step(method_step) {
  return li(
    toList([
      class$(
        "marker:text-base w-full justify-self-start list-decimal text-left pl-1 ml-2 leading-snug my-2"
      )
    ]),
    toList([text(method_step.step_text)])
  );
}
function view_tag(tag) {
  return div(
    toList([class$("flex")]),
    toList([
      div(
        toList([
          class$(
            "font-mono bg-ecru-white-100 border border-ecru-white-950 px-1 text-xs"
          )
        ]),
        toList([text(tag.name)])
      ),
      div(
        toList([
          class$(
            "font-mono bg-ecru-white-50 border border-l-0 border-ecru-white-950  px-1 text-xs"
          )
        ]),
        toList([text(tag.value)])
      )
    ])
  );
}
function view_recipe_detail(recipe) {
  return section(
    toList([
      class$(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[fit-content(100px)_fit-content(100px)_1fr]"
      )
    ]),
    toList([
      page_title(recipe.title, "underline-green"),
      fieldset(
        toList([
          class$(
            "mx-2 sm:mx-0 mt-0 sm:mt-4 flex sm:flex-wrap justify-between row-start-2 col-span-full sm:row-start-1 sm:col-span-3 sm:col-start-9"
          )
        ]),
        toList([
          fieldset(
            toList([
              class$("flex flex-wrap sm:justify-between items-baseline mb-2")
            ]),
            toList([
              label(
                toList([
                  for$("prep_time"),
                  class$("justify-self-start font-mono italic")
                ]),
                toList([text("Prep:")])
              ),
              div(
                toList([class$("mx-4 justify-self-start")]),
                toList([text(to_string3(recipe.prep_time))])
              )
            ])
          ),
          fieldset(
            toList([
              class$("flex flex-wrap sm:justify-between items-baseline mb-2")
            ]),
            toList([
              label(
                toList([
                  for$("cook_time"),
                  class$("justify-self-start font-mono italic")
                ]),
                toList([text("Cook:")])
              ),
              div(
                toList([class$("mx-4 justify-self-start")]),
                toList([text(to_string3(recipe.cook_time))])
              )
            ])
          ),
          fieldset(
            toList([
              class$("flex flex-wrap sm:justify-between items-baseline mb-2")
            ]),
            toList([
              label(
                toList([
                  for$("cook_time"),
                  class$("justify-self-start font-mono italic")
                ]),
                toList([text("Serves:")])
              ),
              div(
                toList([class$("mx-4 justify-self-start")]),
                toList([text(to_string3(recipe.serves))])
              )
            ])
          )
        ])
      ),
      nav(
        toList([
          class$(
            "flex flex-col justify-start items-middle col-span-1 col-start-12 text-base md:text-lg mt-4"
          )
        ]),
        toList([
          a(toList([href("/"), class$("text-center")]), toList([text("\u{1F3E0}")])),
          a(
            toList([
              href("/recipes/" + recipe.slug + "/edit"),
              class$("text-center")
            ]),
            toList([text("\u270F\uFE0F")])
          )
        ])
      ),
      fieldset(
        toList([
          class$(
            "flex flex-wrap gap-1 items-baseline mx-1 col-span-full gap-x-3"
          )
        ]),
        (() => {
          let $ = recipe.tags;
          if ($ instanceof Some) {
            let a$1 = $[0];
            return map3(a$1, (tag) => {
              return view_tag(tag);
            });
          } else {
            return toList([none3()]);
          }
        })()
      ),
      fieldset(
        toList([
          class$(
            "col-span-full my-1 mb-6 pt-1 pb-2 px-2 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-6 [box-shadow:1px_1px_0_#a3d2ab] mr-1"
          )
        ]),
        toList([
          legend(
            toList([class$("mx-2 px-1 font-mono italic")]),
            toList([text("Ingredients")])
          ),
          (() => {
            let _pipe = recipe.ingredients;
            let _pipe$1 = map(
              _pipe,
              (_capture) => {
                return map_values(
                  _capture,
                  (_, item) => {
                    return view_ingredient(item);
                  }
                );
              }
            );
            let _pipe$2 = map(_pipe$1, values);
            let _pipe$3 = map(_pipe$2, fragment);
            return unwrap(_pipe$3, none3());
          })()
        ])
      ),
      fieldset(
        toList([
          class$(
            "flex justify-start flex-wrap col-span-full my-1 mb-6 pt-1 pb-2 px-2 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-6 [box-shadow:1px_1px_0_#a3d2ab] mr-1"
          )
        ]),
        toList([
          legend(
            toList([class$("mx-2 px-1 font-mono italic")]),
            toList([text("Method")])
          ),
          ol(
            toList([
              class$(
                "list-decimal flex flex-wrap w-full items-baseline col-span-full pr-1 pl-2 ml-1 mb-1"
              )
            ]),
            toList([
              (() => {
                let _pipe = recipe.method_steps;
                let _pipe$1 = map(
                  _pipe,
                  (_capture) => {
                    return map3(_capture, view_method_step);
                  }
                );
                let _pipe$2 = unwrap(_pipe$1, toList([none3()]));
                return fragment(_pipe$2);
              })()
            ])
          )
        ])
      )
    ])
  );
}
function lookup_and_view_recipe(maybe_recipe) {
  if (maybe_recipe instanceof Some) {
    let a$1 = maybe_recipe[0];
    return view_recipe_detail(a$1);
  } else {
    return page_title("Recipe not found", "");
  }
}
function json_encode_ingredient(ingredient) {
  return object2(
    toList([
      ["name", string2(unwrap(ingredient.name, ""))],
      ["quantity", string2(unwrap(ingredient.quantity, ""))],
      ["units", string2(unwrap(ingredient.units, ""))],
      [
        "ismain",
        string2(to_string5(unwrap(ingredient.ismain, false)))
      ]
    ])
  );
}
function json_encode_ingredient_list(dict2) {
  let _pipe = dict2;
  let _pipe$1 = map_to_list(_pipe);
  let _pipe$2 = map3(
    _pipe$1,
    (pair) => {
      return [to_string3(pair[0]), json_encode_ingredient(pair[1])];
    }
  );
  return object2(_pipe$2);
}
function save_recipe(recipe) {
  let js_recipe = new JSRecipe(
    unwrap(recipe.id, ""),
    recipe.title,
    recipe.slug,
    recipe.cook_time,
    recipe.prep_time,
    recipe.serves,
    unwrap(
      map(recipe.tags, toArray),
      toArray(toList([]))
    ),
    (() => {
      let _pipe = recipe.ingredients;
      return nullable(_pipe, json_encode_ingredient_list);
    })(),
    unwrap(
      map(recipe.method_steps, toArray),
      toArray(toList([]))
    )
  );
  return from2(
    (dispatch2) => {
      addOrUpdateRecipe(js_recipe);
      let _pipe = new DbSavedUpdatedRecipe(recipe);
      return dispatch2(_pipe);
    }
  );
}
function detail_update(model, msg) {
  if (msg instanceof UserUpdatedRecipeTitle) {
    let newtitle = msg[0];
    if (model instanceof Some) {
      let a$1 = model[0];
      return [new Some(a$1.withFields({ title: newtitle })), none()];
    } else {
      return [model, none()];
    }
  } else if (msg instanceof UserUpdatedRecipePrepTimeHrs) {
    let newpreptimehrs = msg[0];
    if (model instanceof Some) {
      let a$1 = model[0];
      return [
        new Some(
          a$1.withFields({
            prep_time: (() => {
              let _pipe = newpreptimehrs;
              let _pipe$1 = parse(_pipe);
              let _pipe$2 = map2(
                _pipe$1,
                (b) => {
                  return b * 60 + remainderInt(a$1.prep_time, 60);
                }
              );
              return unwrap2(_pipe$2, 0);
            })()
          })
        ),
        none()
      ];
    } else {
      return [model, none()];
    }
  } else if (msg instanceof UserUpdatedRecipePrepTimeMins) {
    let newpreptimemins = msg[0];
    if (model instanceof Some) {
      let a$1 = model[0];
      return [
        new Some(
          a$1.withFields({
            prep_time: (() => {
              let _pipe = newpreptimemins;
              let _pipe$1 = parse(_pipe);
              let _pipe$2 = map2(
                _pipe$1,
                (b) => {
                  return a$1.prep_time - remainderInt(a$1.prep_time, 60) + b;
                }
              );
              return unwrap2(_pipe$2, 0);
            })()
          })
        ),
        none()
      ];
    } else {
      return [model, none()];
    }
  } else if (msg instanceof UserUpdatedRecipeCookTimeHrs) {
    let newcooktimehrs = msg[0];
    if (model instanceof Some) {
      let a$1 = model[0];
      return [
        new Some(
          a$1.withFields({
            cook_time: (() => {
              let _pipe = newcooktimehrs;
              let _pipe$1 = parse(_pipe);
              let _pipe$2 = map2(
                _pipe$1,
                (b) => {
                  return b * 60 + remainderInt(a$1.cook_time, 60);
                }
              );
              return unwrap2(_pipe$2, 0);
            })()
          })
        ),
        none()
      ];
    } else {
      return [model, none()];
    }
  } else if (msg instanceof UserUpdatedRecipeCookTimeMins) {
    let newcooktimemins = msg[0];
    if (model instanceof Some) {
      let a$1 = model[0];
      return [
        new Some(
          a$1.withFields({
            cook_time: (() => {
              let _pipe = newcooktimemins;
              let _pipe$1 = parse(_pipe);
              let _pipe$2 = map2(
                _pipe$1,
                (b) => {
                  return a$1.cook_time - remainderInt(a$1.cook_time, 60) + b;
                }
              );
              return unwrap2(_pipe$2, 0);
            })()
          })
        ),
        none()
      ];
    } else {
      return [model, none()];
    }
  } else if (msg instanceof UserUpdatedRecipeServes) {
    let newserves = msg[0];
    if (model instanceof Some) {
      let a$1 = model[0];
      return [
        new Some(
          a$1.withFields({
            serves: (() => {
              let _pipe = newserves;
              let _pipe$1 = parse(_pipe);
              return unwrap2(_pipe$1, 0);
            })()
          })
        ),
        none()
      ];
    } else {
      return [model, none()];
    }
  } else if (msg instanceof UserUpdatedIngredientNameAtIndex) {
    let i = msg[0];
    let new_ingredient_name = msg[1];
    if (model instanceof Some) {
      let a$1 = model[0];
      return [
        new Some(
          a$1.withFields({
            ingredients: (() => {
              let _pipe = a$1.ingredients;
              return map(
                _pipe,
                (_capture) => {
                  return dict_update(
                    _capture,
                    i,
                    (ing) => {
                      return ing.withFields({
                        name: new Some(new_ingredient_name)
                      });
                    }
                  );
                }
              );
            })()
          })
        ),
        none()
      ];
    } else {
      return [model, none()];
    }
  } else if (msg instanceof UserSavedUpdatedRecipe) {
    let recipe = msg[0];
    return [
      new Some(recipe),
      save_recipe(recipe.withFields({ slug: kebab_case(recipe.title) }))
    ];
  } else {
    let recipe = msg[0];
    return [new Some(recipe), none()];
  }
}
function decode_stringed_int(d) {
  let decoder = string;
  let _pipe = decoder(d);
  let _pipe$1 = map2(_pipe, parse);
  let _pipe$2 = map2(
    _pipe$1,
    (_capture) => {
      return map_error(
        _capture,
        (_) => {
          return toList([
            new DecodeError(
              "a stringed int",
              "something else",
              toList([""])
            )
          ]);
        }
      );
    }
  );
  return flatten(_pipe$2);
}
function decode_stringed_bool(d) {
  let _pipe = string(d);
  return map2(
    _pipe,
    (a2) => {
      if (a2 === "True") {
        return true;
      } else {
        return false;
      }
    }
  );
}
function decode_ingredient(d) {
  let decoder = decode4(
    (var0, var1, var2, var3) => {
      return new Ingredient(var0, var1, var2, var3);
    },
    optional_field("name", string),
    optional_field("ismain", decode_stringed_bool),
    optional_field("quantity", string),
    optional_field("units", string)
  );
  return decoder(d);
}
function decode_tag(d) {
  let decoder = decode2(
    (var0, var1) => {
      return new Tag(var0, var1);
    },
    field("name", string),
    field("value", string)
  );
  return decoder(d);
}
function decode_method_step(d) {
  let decoder = decode1(
    (var0) => {
      return new MethodStep(var0);
    },
    field("step_text", string)
  );
  return decoder(d);
}
function decode_recipe(d) {
  let decoder = decode9(
    (var0, var1, var2, var3, var4, var5, var6, var7, var8) => {
      return new Recipe(var0, var1, var2, var3, var4, var5, var6, var7, var8);
    },
    optional_field("id", string),
    field("title", string),
    field("slug", string),
    field("cook_time", int),
    field("prep_time", int),
    field("serves", int),
    optional_field("tags", list(decode_tag)),
    optional_field("ingredients", dict(decode_stringed_int, decode_ingredient)),
    optional_field("method_steps", list(decode_method_step))
  );
  debug(d);
  return decoder(d);
}
function get_recipes() {
  return from2(
    (dispatch2) => {
      let _pipe = do_get_recipes();
      let _pipe$1 = map_promise(_pipe, toList);
      let _pipe$2 = map_promise(
        _pipe$1,
        (_capture) => {
          return map3(_capture, decode_recipe);
        }
      );
      let _pipe$3 = map_promise(_pipe$2, debug);
      let _pipe$4 = map_promise(_pipe$3, all);
      let _pipe$5 = map_promise(
        _pipe$4,
        (_capture) => {
          return map2(
            _capture,
            (var0) => {
              return new DbRetrievedRecipes(var0);
            }
          );
        }
      );
      tap(
        _pipe$5,
        (_capture) => {
          return map2(_capture, dispatch2);
        }
      );
      return void 0;
    }
  );
}

// build/dev/javascript/app/app.mjs
var Model2 = class extends CustomType {
  constructor(current_route, current_recipe, recipes) {
    super();
    this.current_route = current_route;
    this.current_recipe = current_recipe;
    this.recipes = recipes;
  }
};
var Home = class extends CustomType {
};
var ViewRecipeDetail = class extends CustomType {
  constructor(slug) {
    super();
    this.slug = slug;
  }
};
var EditRecipeDetail = class extends CustomType {
  constructor(slug) {
    super();
    this.slug = slug;
  }
};
var ViewRecipeList = class extends CustomType {
};
var OnRouteChange = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var RecipeDetail = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var RecipeList = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
function lookup_recipe_by_slug(model, slug) {
  return from_result(
    find2(model.recipes, (a2) => {
      return a2.slug === slug;
    })
  );
}
function update3(model, msg) {
  if (msg instanceof OnRouteChange && msg[0] instanceof ViewRecipeList) {
    return [
      model.withFields({ current_route: new ViewRecipeList() }),
      map4(
        get_recipes(),
        (var0) => {
          return new RecipeList(var0);
        }
      )
    ];
  } else if (msg instanceof OnRouteChange && msg[0] instanceof ViewRecipeDetail) {
    let slug = msg[0].slug;
    return [
      model.withFields({
        current_route: new ViewRecipeDetail(slug),
        current_recipe: lookup_recipe_by_slug(model, slug)
      }),
      none()
    ];
  } else if (msg instanceof OnRouteChange && msg[0] instanceof EditRecipeDetail) {
    let slug = msg[0].slug;
    return [
      model.withFields({
        current_route: new EditRecipeDetail(slug),
        current_recipe: lookup_recipe_by_slug(model, slug)
      }),
      none()
    ];
  } else if (msg instanceof OnRouteChange) {
    let route = msg[0];
    return [
      model.withFields({ current_route: route, current_recipe: new None() }),
      none()
    ];
  } else if (msg instanceof RecipeList) {
    let list_msg = msg[0];
    let $ = list_update(model.recipes, list_msg);
    let child_model = $[0];
    let child_effect = $[1];
    return [
      model.withFields({ recipes: child_model }),
      map4(child_effect, (var0) => {
        return new RecipeList(var0);
      })
    ];
  } else if (msg instanceof RecipeDetail && msg[0] instanceof DbSavedUpdatedRecipe) {
    let new_recipe = msg[0][0];
    return [
      model,
      batch(
        toList([
          map4(
            get_recipes(),
            (var0) => {
              return new RecipeList(var0);
            }
          ),
          from2(
            (dispatch2) => {
              let _pipe = new OnRouteChange(
                new ViewRecipeDetail(new_recipe.slug)
              );
              return dispatch2(_pipe);
            }
          )
        ])
      )
    ];
  } else {
    let detail_msg = msg[0];
    let $ = detail_update(model.current_recipe, detail_msg);
    let child_model = $[0];
    let child_effect = $[1];
    return [
      model.withFields({ current_recipe: child_model }),
      map4(child_effect, (var0) => {
        return new RecipeDetail(var0);
      })
    ];
  }
}
function on_route_change(uri) {
  let $ = path_segments(uri.path);
  if ($.hasLength(3) && $.head === "recipes" && $.tail.tail.head === "edit") {
    let slug = $.tail.head;
    return new OnRouteChange(new EditRecipeDetail(slug));
  } else if ($.hasLength(2) && $.head === "recipes") {
    let slug = $.tail.head;
    return new OnRouteChange(new ViewRecipeDetail(slug));
  } else if ($.hasLength(1) && $.head === "recipes") {
    return new OnRouteChange(new ViewRecipeList());
  } else {
    return new OnRouteChange(new Home());
  }
}
function init6(_) {
  return [
    new Model2(new Home(), new None(), toList([])),
    init2(on_route_change)
  ];
}
function view_base(children) {
  return main(
    toList([
      class$(
        "grid ml-1 mr-2 gap-2\n    2xl:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_105ch_[main-end]_3fr_[full-end]_1fr_[end]]\n    xl:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_95ch_[main-end]_3fr_[full-end]_1fr_[end]]\n    lg:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_85ch_[main-end]_3fr_[full-end]_1fr_[end]]\n    md:grid-cols-[[start_full-start]_1fr_[main-start]_85ch_[main-end]_1fr_[full-end_end]]\n    grid-cols-[[start_full-start_main-start]_100%_[main-end_full-end_end]]\n    min-h-[90vh]"
      )
    ]),
    toList([children])
  );
}
function view_home() {
  return section(
    toList([class$("grid-cols-12 col-start-[main-start]")]),
    toList([
      page_title(
        "Mealstack",
        "text-9xl placeholder:underline-pink underline-pink col-span-full xxs:col-span-11"
      ),
      nav(
        toList([
          class$(
            "subgrid-cols my-6 gap-y-12 col-span-full text-6xl mx-2 font-mono"
          )
        ]),
        toList([
          a(
            toList([
              class$(
                "flex items-baseline col-span-full sm:col-span-6 justify-between pr-4"
              ),
              href("/planner")
            ]),
            toList([
              span(toList([class$("underline-orange")]), toList([text("Plan")])),
              span(toList([class$("text-5xl")]), toList([text("\u{1F4C5}")]))
            ])
          ),
          a(
            toList([
              class$(
                "flex items-baseline col-span-full sm:col-span-6 justify-between pr-4"
              ),
              href("/recipes")
            ]),
            toList([
              span(toList([class$("underline-green")]), toList([text("Book")])),
              span(toList([class$("text-5xl")]), toList([text("\u{1F4D1}")]))
            ])
          ),
          a(
            toList([
              class$(
                "flex items-baseline col-span-full sm:col-span-6 justify-between pr-4"
              ),
              href("/recipes/new")
            ]),
            toList([
              span(toList([class$("underline-blue")]), toList([text("New")])),
              span(toList([class$("text-5xl")]), toList([text("\u{1F4DD}")]))
            ])
          ),
          a(
            toList([
              class$(
                "flex items-baseline col-span-full sm:col-span-6 justify-between pr-4"
              ),
              href("/import")
            ]),
            toList([
              span(
                toList([class$("underline-yellow")]),
                toList([text("Import")])
              ),
              span(toList([class$("text-5xl")]), toList([text("\u{1F4E9}")]))
            ])
          )
        ])
      )
    ])
  );
}
function view2(model) {
  let page = (() => {
    let $ = model.current_route;
    if ($ instanceof Home) {
      return view_home();
    } else if ($ instanceof ViewRecipeList) {
      return map6(
        view_recipe_list(model.recipes),
        (var0) => {
          return new RecipeList(var0);
        }
      );
    } else if ($ instanceof ViewRecipeDetail) {
      return map6(
        lookup_and_view_recipe(model.current_recipe),
        (var0) => {
          return new RecipeDetail(var0);
        }
      );
    } else {
      return map6(
        lookup_and_edit_recipe(model.current_recipe),
        (var0) => {
          return new RecipeDetail(var0);
        }
      );
    }
  })();
  return view_base(page);
}
function main2() {
  let $ = single2("main");
  if (!$.isOk()) {
    throw makeError(
      "assignment_no_match",
      "app",
      26,
      "main",
      "Assignment pattern did not match",
      { value: $ }
    );
  }
  let main$1 = $[0];
  let _pipe = application(init6, update3, view2);
  let _pipe$1 = wrap(_pipe, main$1);
  let _pipe$2 = start3(_pipe$1, "#app", void 0);
  return activate(_pipe$2, main$1);
}

// build/.lustre/entry.mjs
main2();
