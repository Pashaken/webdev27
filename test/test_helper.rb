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
