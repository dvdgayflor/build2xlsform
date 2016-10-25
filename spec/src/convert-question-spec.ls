# work around livescript syntax.
test = it

{ new-context, convert-question } = require('../lib/convert')

# this file is largely structured after the xlsform reference spec at:
# http://xlsform.org/ref-table/
#
# the grouping and ordering of tests reflect that table. the individual
# tests themselves in turn take after the structure of Build's UI. this
# ensures that tests are in a predictable, sensible order but also that
# every feature supported by Build is represented as expected here.
#
# some internal considerations, like pruning of noisy false fields, are
# tested at the very end, as are pass-on output like seen-fields.

# if you don't care about the context, this is a convenience overload.
convert-simple = -> convert-question(it, new-context())

# type conversion does a number of things.
describe \type ->
  test \text ->
    result = { type: \inputText } |> convert-simple
    expect(result.type).toBe(\text)

  test 'number: integer' ->
    explicit = { type: \inputNumeric, kind: \Integer } |> convert-simple
    expect(explicit.type).toBe(\integer)

    implicit = { type: \inputNumeric } |> convert-simple
    expect(implicit.type).toBe(\integer)

  test 'number: decimal' ->
    result = { type: \inputNumeric, kind: \Decimal } |> convert-simple
    expect(result.type).toBe(\decimal)

  test \date ->
    result = { type: \inputDate } |> convert-simple
    expect(result.type).toBe(\date)

  test \location ->
    result = { type: \inputLocation } |> convert-simple
    expect(result.type).toBe(\geopoint)

  test 'media: image' ->
    explicit = { type: \inputMedia, kind: \Image } |> convert-simple
    expect(explicit.type).toBe(\image)

    implicit = { type: \inputMedia } |> convert-simple
    expect(implicit.type).toBe(\image)

  test 'media: audio' ->
    result = { type: \inputMedia, kind: \Audio } |> convert-simple
    expect(result.type).toBe(\audio)

  test 'media: video' ->
    result = { type: \inputMedia, kind: \Video } |> convert-simple
    expect(result.type).toBe(\video)

  test \barcode ->
    result = { type: \inputBarcode } |> convert-simple
    expect(result.type).toBe(\barcode)

  test \metadata ->
    deviceid = { type: \metadata, kind: 'Device Id' } |> convert-simple
    expect(deviceid.type).toBe(\deviceid)

    start = { type: \metadata, kind: 'Start Time' } |> convert-simple
    expect(start.type).toBe(\start)

    end = { type: \metadata, kind: 'End Time' } |> convert-simple
    expect(end.type).toBe(\end)

  test 'select one' ->
    basic = { name: \test_select, type: \inputSelectOne, options: [] } |> convert-simple
    expect(basic.type).toBe('select_one choices_test_select')

    prefix = [ \nest_a, \nest_b ]
    nested = convert-question({ name: \my_select, type: \inputSelectOne, options: [] }, new-context(), prefix)
    expect(nested.type).toBe('select_one choices_nest_a_nest_b_my_select')

  test 'select multiple' ->
    basic = { name: \test_select, type: \inputSelectMany, options: [] } |> convert-simple
    expect(basic.type).toBe('select_multiple choices_test_select')

    prefix = [ \nest_a, \nest_b ]
    nested = convert-question({ name: \my_select, type: \inputSelectMany, options: [] }, new-context(), prefix)
    expect(nested.type).toBe('select_multiple choices_nest_a_nest_b_my_select')

  # group is tested here despite the final output being wonky, as we still want
  # to verify the intermediate form.
  test \group ->
    non-looping = { type: \group } |> convert-simple
    expect(non-looping.type).toBe(\group)

    looping = { type: \group, loop: true } |> convert-simple
    expect(looping.type).toBe(\repeat)
    expect(looping.loop).toBe(undefined)

describe \name ->
  test 'passthrough' ->
    result = { type: \inputNumber, name: \my_test_question } |> convert-simple
    expect(result.name).toBe(\my_test_question)

describe \label ->
  test 'multilingual passthrough' ->
    result = { type: \inputNumber, label: { en: \thanks, sv: \tack } } |> convert-simple
    expect(result.label).toEqual({ en: \thanks, sv: \tack })

describe \hint ->
  test 'multilingual passthrough' ->
    result = { type: \inputNumber, hint: { en: \thanks, sv: \tack } } |> convert-simple
    expect(result.hint).toEqual({ en: \thanks, sv: \tack })

  test 'empty pruning' ->
    result = { type: \inputNumber, hint: {} } |> convert-simple
    expect(result.hint).toEqual(undefined)

describe \constraint ->
  test 'custom constraint passthrough' ->
    result = { type: \inputNumber, constraint: '. > 3' } |> convert-simple
    expect(result.constraint).toBe('(. > 3)')

  # n.b. there is a bug in build that exposes ui options for inclusivity that should not be there.
  test 'build text length constraint generation' ->
    result = { type: \inputText, length: { min: 42, max: 345 } } |> convert-simple
    expect(result.constraint).toBe('(regex(., "^.{42,345}$"))')

  test 'build text length false pruning' ->
    result = { type: \inputText, length: false } |> convert-simple
    expect(result.constraint).toBe(undefined)

  test 'build number/date range constraint generation (incl/excl combo)' ->
    result = { type: \inputNumber, range: { min: 3, minInclusive: true, max: 9 } } |> convert-simple
    expect(result.constraint).toBe('(. >= 3) and (. < 9)')

  test 'build number/date range constraint generation (excl/incl combo)' ->
    result = { type: \inputNumber, range: { min: 3, max: 9, maxInclusive: true } } |> convert-simple
    expect(result.constraint).toBe('(. > 3) and (. <= 9)')

  test 'build number/date range false pruning' ->
    result = { type: \inputText, range: false } |> convert-simple
    expect(result.constraint).toBe(undefined)

  test 'custom constraint merging with build generation' ->
    result = { type: \inputNumber, constraint: '. != 5' range: { min: 3, max: 9 } } |> convert-simple
    expect(result.constraint).toBe('(. != 5) and (. > 3) and (. < 9)')

describe 'constraint message' ->
  test 'multilingual passthrough' ->
    result = { type: \inputNumber, invalidText: { en: \fun, sv: \roligt } } |> convert-simple
    expect(result.invalidText).toEqual(undefined)
    expect(result.constraint_message).toEqual({ en: \fun, sv: \roligt })

  test 'empty pruning' ->
    result = { type: \inputNumber, invalidText: {} } |> convert-simple
    expect(result.invalidText).toEqual(undefined)
    expect(result.constraint_message).toEqual(undefined)

describe 'required' ->
  test 'true becomes yes' ->
    result = { type: \inputText, required: true } |> convert-simple
    expect(result.required).toEqual(\yes)

  test 'false becomes nothing' ->
    falsy = { type: \inputText, required: false } |> convert-simple
    expect(falsy.required).toEqual(undefined)

