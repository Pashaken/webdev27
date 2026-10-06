require "test_helper"

class UiTest < ActionDispatch::IntegrationTest
  test "style guide renders" do
    get "/ui"
    assert_response :success
  end

  test "every board has 64 squares" do
    get "/ui"

    assert_select ".board" do |boards|
      assert_operator boards.size, :>=, 3
      boards.each { |board| assert_equal 64, board.css(".square").size }
    end
  end

  test "board marks squares and shows coordinates" do
    get "/ui"

    assert_select ".square.is-selected", minimum: 1
    assert_select ".square.is-target", minimum: 1
    assert_select ".square.is-capture", minimum: 1
    assert_select ".square.is-last-move", minimum: 1
    assert_select ".square.is-check", minimum: 1
    assert_select ".square[data-file]", minimum: 16
    assert_select ".square[data-rank]", minimum: 16
  end

  test "board supports interaction states" do
    get "/ui"

    assert_select ".square.is-clickable", minimum: 1
    assert_select ".square.is-drop", minimum: 1
    assert_select ".piece.is-dragging", minimum: 1
    assert_select ".piece.is-draggable", minimum: 1
  end

  test "all twelve pieces are available" do
    get "/ui"

    %w[wk wq wr wb wn wp bk bq br bb bn bp].each do |piece|
      assert_select ".piece[data-piece='#{piece}']", minimum: 1
    end
  end

  test "dice show every face and state" do
    get "/ui"

    (1..6).each { |value| assert_select "button.die[data-value='#{value}']", minimum: 1 }
    assert_select "button.die.is-selected[aria-pressed='true']"
    assert_select "button.die.is-blocked[disabled]"
    assert_select "button.die.is-rolling"
  end

  test "game dialogs render" do
    get "/ui"

    assert_select "#promotion-title"
    assert_select ".promotion-choice", 4
    %w[win loss draw].each { |outcome| assert_select ".result-#{outcome} .result-title" }
  end

  test "lobby, states, menu and icons render" do
    get "/ui"

    assert_select ".game-card", minimum: 3
    assert_select ".spinner"
    assert_select ".skeleton"
    assert_select ".empty"
    assert_select ".waiting"
    assert_select "details.menu .menu-item", minimum: 3
    assert_select "[data-tooltip]", minimum: 2
    %w[x check menu plus flag equal swap refresh dice user contrast].each do |name|
      assert_select ".icon-#{name}"
    end
  end

  test "layout loads all kit files and theme toggle" do
    get login_path

    %w[tokens base components icons game].each do |name|
      assert_select "link[rel=stylesheet][href='/ui/#{name}.css']"
    end
    assert_select "script[src='/ui/theme.js']"
    assert_select "button[data-theme-toggle]"
  end
end
