require "test_helper"

class EloRatingExpectedScoreTest < ActiveSupport::TestCase
  test "equal ratings give an even chance" do
    assert_in_delta 0.5, EloRating.expected_score(1500, 1500), 0.0001
  end

  test "the stronger player is expected to score more" do
    assert_operator EloRating.expected_score(1700, 1500), :>, 0.5
    assert_operator EloRating.expected_score(1500, 1700), :<, 0.5
  end

  test "expectations of two players add up to one" do
    sum = EloRating.expected_score(1620, 1480) + EloRating.expected_score(1480, 1620)

    assert_in_delta 1.0, sum, 0.0001
  end

  test "a 400 point gap means about 91 percent" do
    assert_in_delta 0.909, EloRating.expected_score(1900, 1500), 0.001
  end
end

class EloRatingDeltaTest < ActiveSupport::TestCase
  test "a win against an equal opponent gives half of k" do
    assert_equal 16, EloRating.delta(1500, 1500, 1.0)
  end

  test "a loss against an equal opponent takes half of k" do
    assert_equal(-16, EloRating.delta(1500, 1500, 0.0))
  end

  test "a draw between equals changes nothing" do
    assert_equal 0, EloRating.delta(1500, 1500, 0.5)
  end

  test "an upset win gives more than a win over a weaker opponent" do
    upset = EloRating.delta(1400, 1700, 1.0)
    routine = EloRating.delta(1700, 1400, 1.0)

    assert_operator upset, :>, routine
  end

  test "k factor scales the change" do
    assert_equal 10, EloRating.delta(1500, 1500, 1.0, k: 20)
  end
end
