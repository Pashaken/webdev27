require "test_helper"

class UiHelperTest < ActionView::TestCase
  test "board_squares starts from a8 for white and from h1 when flipped" do
    squares = board_squares
    assert_equal 64, squares.uniq.size
    assert_equal "a8", squares.first
    assert_equal "h1", squares.last

    flipped = board_squares(flipped: true)
    assert_equal "h1", flipped.first
    assert_equal "a8", flipped.last
  end

  test "square_tone matches real board colors" do
    assert_equal "dark", square_tone("a1")
    assert_equal "light", square_tone("h1")
    assert_equal "light", square_tone("a8")
    assert_equal "light", square_tone("e4")
    assert_equal "dark", square_tone("d4")
  end

  test "fen_pieces reads piece placement" do
    pieces = fen_pieces("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")

    assert_equal 32, pieces.size
    assert_equal "wp", pieces["e4"]
    assert_equal "bk", pieces["e8"]
    assert_equal "wr", pieces["h1"]
    assert_nil pieces["e2"]
  end

  test "piece_label has a name for every piece" do
    %w[wk wq wr wb wn wp bk bq br bb bn bp].each do |piece|
      assert_predicate piece_label(piece), :present?
    end
  end
end
