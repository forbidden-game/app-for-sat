export const errorModeEnum = [
  "unknown",
  "setup_equation",
  "translate_words_to_math",
  "algebra_manipulation",
  "sign_error",
  "fraction_error",
  "exponent_root_rules",
  "function_interpretation",
  "graph_reading",
  "geometry_relation",
  "units_or_conversion",
  "compute_arithmetic",
  "inequality_direction",
  "casework_missing",
  "choose_option_mapping",
  "constraint_missed",
  "careless_copying",
  "time_pressure_guess",
] as const;

export type ErrorModeEnum = (typeof errorModeEnum)[number];
