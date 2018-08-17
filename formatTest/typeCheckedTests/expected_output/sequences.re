/* Copyright (c) 2015-present, Facebook, Inc. All rights reserved. */

/**
 * Testing Sequences.
 */
let result = {
  let twenty = 20;
  let result = twenty;
  result;
};

/* Final semicolon is not required */
let result = {
  let twenty = result;
  twenty;
};
let anInt = result + 20;

let twenty = 20;

/**
 * Each of these are a sequence with a single item - they will be
 * printed in reduced form because sequences are a *parse* time construct.
 * To ensure these are parsed correctly, adding to an integer.
 */
let result = 0 + twenty;
let result = 0 + twenty;
let result = 0 + twenty;

let unitValue = ();
/* While loops/for loops merely accept a "simple expression" (which means
 * it is either a simple token or balanced with parens/braces). However,
 * the formatter ensures that the bodies are printed in "sequence" form even if
 * it's not required.
 */
while (false) {
  unitValue;
};
while (false) {
  print_string("test");
};
while (false) {
  print_string("test");
};

type myRecord = {number: int};
let x = {number: 20};
let number = 20;
/*
 * The (mild) consequence of not requiring a final semi in a sequence,
 * is that we can no longer "pun" a single field record (which would)
 * be very rare anyways.
 */
let cannotPunASingleFieldRecord = {
  number: number,
};
let fourty =
  20 + cannotPunASingleFieldRecord.number;
let thisIsASequenceNotPunedRecord = number;
let fourty = 20 + thisIsASequenceNotPunedRecord;

type recordType = {
  a: int,
  b: int,
  c: int,
};
let a = 0;
let b = 0;
let c = 0;
/* All of these will be printed as punned because they have more than one field. */
let firstFieldPunned = {a, b, c};
let sndFieldPunned = {a, b, c};
let thirdFieldPunned = {a, b, c};
let singlePunAcceptedIfExtended = {
  ...firstFieldPunned,
  a,
};

module Option = {
  let map = (x, f) =>
    switch (x) {
    | Some(x) => Some(f(x))
    | None => None
    };

  let flatMap = (x, f) =>
    switch (x) {
    | Some(x) => f(x)
    | None => None
    };

  let pair = (x, y) =>
    switch (x, y) {
    | (Some(x), Some(y)) => Some((x, y))
    | _ => None
    };
};

let opt = (Option.flatMap, Option.pair);
let opt_map = (Option.map, Option.pair);

let _ =
  (Pervasives.fst(opt))(Some(10), x =>
    (Pervasives.fst(opt_map))(
      (Pervasives.snd(opt_map))(
        (Pervasives.snd(opt_map))(
          Some(2),
          Some(5),
        ),
        Some(7),
      ),
      (((a, b), c)) => {
        print_endline(string_of_int(a));

        a + x * b + c;
      },
    )
  );
