import type * as _ from "../gleam.d.mts";

export class Some<FQ> extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: FQ);
  /** @deprecated */
  0: FQ;
}
export function Option$Some<FQ>($0: FQ): Option$<FQ>;
export function Option$isSome<FQ>(value: Option$<FQ>): boolean;
export function Option$Some$0<FQ>(value: Option$<FQ>): FQ;

export class None extends _.CustomType {}
export function Option$None<FQ>(): Option$<FQ>;
export function Option$isNone<FQ>(value: Option$<FQ>): boolean;

export type Option$<FQ> = Some<FQ> | None;

export function all<FR>(list: _.List<Option$<FR>>): Option$<_.List<FR>>;

export function is_some(option: Option$<any>): boolean;

export function is_none(option: Option$<any>): boolean;

export function to_result<GN, GQ>(option: Option$<GN>, e: GQ): _.Result<GN, GQ>;

export function from_result<GT>(result: _.Result<GT, any>): Option$<GT>;

export function unwrap<GY>(option: Option$<GY>, default$: GY): GY;

export function lazy_unwrap<HA>(option: Option$<HA>, default$: () => HA): HA;

export function map<HC, HE>(option: Option$<HC>, fun: (x0: HC) => HE): Option$<
  HE
>;

export function flatten<HG>(option: Option$<Option$<HG>>): Option$<HG>;

export function then$<HK, HM>(option: Option$<HK>, fun: (x0: HK) => Option$<HM>): Option$<
  HM
>;

export function or<HP>(first: Option$<HP>, second: Option$<HP>): Option$<HP>;

export function lazy_or<HT>(first: Option$<HT>, second: () => Option$<HT>): Option$<
  HT
>;

export function values<HX>(options: _.List<Option$<HX>>): _.List<HX>;
