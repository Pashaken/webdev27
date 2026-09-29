require 'pg'

class Database
  def self.connect
    @connection ||= PG.connect(
      dbname: 'dicechess_db', 
      user: 'postgres', 
      password: '', 
      host: 'localhost',
      port: 5432
    )
  rescue PG::Error => e
    puts "Ошибка подключения к PostgreSQL: #{e.message}"
    exit
  end
end
