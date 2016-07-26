# coding: utf-8
require "thor"
require 'pdf_forms'
require 'yaml'
require 'colorize'
require 'open3'
require 'fileutils'

module Limarka

  class Conversor
    attr_accessor :opcoes
    attr_accessor :preambulo_tex
    attr_accessor :pretextual_tex
    attr_accessor :postextual_tex
    attr_accessor :texto_tex
    def initialize(opcoes)
      self.opcoes = opcoes
    end

    def convert
      FileUtils.mkdir_p(opcoes[:output_dir])
      preambulo
      pretextual
      postextual
      textual
    end

    def hash_to_yaml(h)
      s = StringIO.new
      s << h.to_yaml
      s << "---\n\n"
      s.string
    end
    
    PREAMBULO="templates/preambulo.tex"
    def preambulo
      Open3.popen3("pandoc -f markdown --data-dir=. --template=preambulo -t latex") do |stdin, stdout, stderr, wait_thr|
        stdin.write(hash_to_yaml(opcoes[:configuracao]))
        stdin.close
        @preambulo_tex = stdout.read
        exit_status = wait_thr.value # Process::Status object returned.
        if(exit_status!=0) then puts ("Erro: " + stderr.read).red end
      end
      File.open(preambulo_tex_file, 'w') { |file| file.write(@preambulo_tex) }
    end

    PRETEXTUAL = "templates/pretextual.tex"

    def pretextual
      s = StringIO.new
      necessita_de_arquivo_de_texto = ["errata"]
      ["folha_de_rosto", "errata", "folha_de_aprovacao", "dedicatoria", "agradecimentos", 
      "epigrafe", "resumo", "abstract", "lista_ilustracoes", "lista_tabelas", 
      "lista_siglas", "lista_simbolos", "sumario"].each_with_index do |secao,indice|
        template = "pretextual#{indice+1}-#{secao}"
        Open3.popen3("pandoc -f markdown --data-dir=. --template=#{template} -t latex") {|stdin, stdout, stderr, wait_thr|
          stdin.write(hash_to_yaml(opcoes[:configuracao]))
          stdin.write("\n")
          if necessita_de_arquivo_de_texto.include?(secao) then
            arquivo_de_entrada = "#{secao}.md"

            conteudo = File.read(arquivo_de_entrada)
            stdin.write(conteudo)
          end
          stdin.close
          s << stdout.read
          exit_status = wait_thr.value # Process::Status object returned.
          if(exit_status!=0) then puts ("Erro: " + stderr.read).red end
        }
      end
      @pretextual_tex = s.string
      File.open(pretextual_tex_file, 'w') { |file| file.write(pretextual_tex) }
#      puts "#{PRETEXTUAL} criado".green
    end

    POSTEXTUAL = "templates/postextual.tex"
    def postextual
      # Referências (obrigatório)
      # Glossário (opcional)
      # Apêndice (opcional)
      # Anexo (opcional)
      # Índice (opcional)

      s = StringIO.new

      necessita_de_arquivo_de_texto = ["referencias", "apendices","anexos"]
      ["referencias", "glossario", "apendices", "anexos", "indice"].each_with_index do |secao,indice|
        template = "postextual#{indice+1}-#{secao}"
        Open3.popen3("pandoc -f markdown --data-dir=. --template=#{template} --chapter -t latex") {|stdin, stdout, stderr, wait_thr|
          stdin.write(hash_to_yaml(opcoes[:configuracao]))
          stdin.write("\n")
          if necessita_de_arquivo_de_texto.include?(secao) then
            arquivo_de_entrada = "#{secao}.md"
            conteudo = File.read(arquivo_de_entrada)
            stdin.write(conteudo)
          end
          stdin.close
          s << stdout.read
          exit_status = wait_thr.value # Process::Status object returned.
          if(exit_status!=0) then puts ("Erro: " + stderr.read).red end
        }
      end

      # arquivo temporário de referencias
      if(opcoes[:referencias_bib]) then
        File.open(referencias_bib_file, 'w') { |file| file.write(opcoes[:referencias_bib]) }
      end
      
      @postextual_tex = s.string
      File.open(postextual_tex_file, 'w') { |file| file.write(postextual_tex) }
    end

    def textual
      valida_yaml
      Open3.popen3("pandoc -f markdown+raw_tex -t latex -s --normalize --chapter --include-in-header=#{preambulo_tex_file} --include-before-body=#{pretextual_tex_file}  --include-after-body=#{postextual_tex_file}") {|stdin, stdout, stderr, wait_thr|
        stdin.write(File.read('templates/configuracao-tecnica.yaml'))
        stdin.write("\n")
        stdin.write(hash_to_yaml(opcoes[:configuracao]))
        stdin.write("\n")
        stdin.write(opcoes[:texto])
        stdin.close
        @texto_tex = stdout.read
        exit_status = wait_thr.value # Process::Status object returned.
        if(exit_status!=0) then puts ("Erro: " + stderr.read).red end
      }
      File.open(texto_tex_file, 'w')  { |f| f.write(@texto_tex)}
    end

    
    def preambulo_tex_file
      "#{opcoes[:output_dir]}/xxx-preambulo.tex"
    end
    def pretextual_tex_file
      "#{opcoes[:output_dir]}/xxx-pretextual.tex"
    end
    def postextual_tex_file
      "#{opcoes[:output_dir]}/xxx-postextual.tex"
    end
    
    def texto_tex_file
      "#{opcoes[:output_dir]}/xxx-Monografia.tex"
    end
    def pdf_file
      "#{opcoes[:output_dir]}/xxx-Monografia.pdf"
    end

    def referencias_bib_file
      "#{opcoes[:output_dir]}/xxx-referencias.bib"
    end
    
    def valida_yaml
      # não faz nada por enquanto
    end
    
  end
end

