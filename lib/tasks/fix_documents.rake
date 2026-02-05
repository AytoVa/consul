namespace :documents do
  desc "Fix broken document attachments"
  task fix_broken: :environment do
    Document.find_each do |doc|
      begin
        # Verificar si el archivo existe en el path actual
        if doc.attachment.path && !File.exist?(doc.attachment.path)
          # Intentar encontrar el archivo con el filename original
          old_path = doc.attachment.path.gsub(File.basename(doc.attachment.path), doc.attachment_file_name)
          
          if File.exist?(old_path)
            puts "Documento #{doc.id}: Copiando de #{old_path} a #{doc.attachment.path}"
            FileUtils.mkdir_p(File.dirname(doc.attachment.path))
            FileUtils.cp(old_path, doc.attachment.path)
          else
            puts "Documento #{doc.id}: Archivo no encontrado - necesita volver a subirse"
          end
        else
          puts "Documento #{doc.id}: OK"
        end
      rescue => e
        puts "Error en documento #{doc.id}: #{e.message}"
      end
    end
  end
end