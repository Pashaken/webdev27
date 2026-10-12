namespace :ui do
  desc "Собрать статическую страницу UI-кита public/ui-kit.html"
  task build: :environment do
    ActionView::Base.annotate_rendered_view_with_filenames = false

    html = ApplicationController.render(template: "ui/index", layout: "ui_static")
    path = Rails.public_path.join("ui-kit.html")
    path.binwrite(html)
    puts "Записано: #{path} (#{html.bytesize} байт)"
  end
end
