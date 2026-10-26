ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    fixtures :all

    RiggedRandom = Struct.new(:values) do
      def rand(_range)
        values.shift
      end
    end

    def rigged(*values)
      RiggedRandom.new(values)
    end

    def start_game(white: users(:alice), black: users(:bob), **settings)
      game = Game.open_for(creator: white, color: "white", **settings)
      game.join!(black)
      game
    end

    def make_move(game, user, dice:, die:, piece:, from: "e2", to: "e4", **options)
      game.roll_dice!(user, random: rigged(*dice))
      game.choose_die!(user, die)
      game.record_move!(user: user, from: from, to: to, piece: piece, san: "#{piece}#{to}", **options)
    end
  end
end

module ActionDispatch
  class IntegrationTest
    teardown { Game.dice_source = Random }

    def sign_in(username)
      open_session.tap do |session|
        as(session) { post login_path, params: { username: username, password: "secret123" } }
      end
    end

    def as(session)
      previous = @integration_session
      @integration_session = session
      yield
    ensure
      @integration_session = previous
    end

    def rig_dice(*values)
      Game.dice_source = ActiveSupport::TestCase::RiggedRandom.new(values)
    end

    def take_turn(session, game, dice:, die:, from:, to:)
      rig_dice(*dice)
      as(session) do
        post roll_game_path(game)
        post choose_game_path(game), params: { die: die }
        post move_game_path(game), params: { from: from, to: to }
      end
    end
  end
end
