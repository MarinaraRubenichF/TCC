library(devtools)
source_url('https://gist.githubusercontent.com/fawda123/7471137/raw/466c1474d0a505ff044412703516c34f1a4684a5/nnet_plot_update.r')
library(gsheet)
library(neuralnet)
library(rio)
library(stringr)

dS  <<- NULL;

shinyServer(function(input, output){
  #------------------------------------------------------------------------------>
  #Lê e mostra os dados do Arquivo
  output$tabela <- DT::renderDataTable({
    inFile <- input$file1
        
    if(is.null(inFile))
      return( NULL)
    # else(incProgress(0.2, detail ="Analisando os Dados"))
    dS <<- import(inFile$datapath)
        
    #Retorna a tabela paginada
    return(DT::datatable(dS))
  }) #Fim output$tbela
  #<------------------------------------------------------------------------------
  
  #------------------------------------------------------------------------------>
  #Possibilita selecionar os atributos (checkboxes) e classe (radiobutton)
  output$atributos <- renderUI({
    inFile <- input$file1
    
    if(is.null(inFile))
      return(NULL)

    dS <<- import(inFile$datapath)
    #Recebe os nomes das colunas do dataset
    nomesdS <- names(dS)
    #Colunas NA recebem o valor 0
    dS[is.na(dS)] = 0
    
    #Retira espaços e caracteres especiais do nome da classe, pois o R não os reconhece
    removeChardS <- function(str) {
      str = str_replace_all(str, fixed(" "),"")
      str = str_replace_all(str, fixed("("),"")
      str = str_replace_all(str, fixed(")"),"")
      str = str_replace_all(str, fixed("-"),"")
      str = str_replace_all(str, fixed("[áàãâä]"),"a")
      str = str_replace_all(str, fixed("[éèêë]"),"e")
      str = str_replace_all(str, fixed("[íìîï]"), "i")
      str = str_replace_all(str, fixed("[óòõôö]"), "o")
      str = str_replace_all(str, fixed("[úùûü]"), "u")
      str = str_replace_all(str, fixed("ç"), "c")
      str = str_replace_all(str, fixed("[,(),;:|!#$%&/=?~^><ªº-]"), "")
      str = str_replace_all(str, fixed("[^a-z0-9]"), "")
      str = str_replace_all(str, fixed("_+/"), "")
      
      return(str);
    }
    #Atribui os nomes novos das colunas ao dataset
    names(dS) <- removeChardS(nomesdS)
    
    #Retorna checkboxes e radiobutton
    return(
      div(h3("Selecionar Variáveis"),
        div(
          h5(strong("Por favor, desmarque o atributo que será a 'Classe' na coluna da esquerda
                    e marque-o na da direita: ")),
          style="color:red; font-weight:200; text-align:justify"
        ),
        splitLayout(
          (checkboxGroupInput(
            "atributos",
            label = h5(strong("Atributos")), choices = colnames(dS), selected = colnames(dS[1:(length(dS)-1)])
          )),
          (radioButtons(
            "classe",
            label = h5(strong("Classe")), choices = colnames(dS), selected = colnames(dS[length(dS)])
          ))
        )
      )
    );
  }) #Fim output$atributos
  #<-------------------------------------------------------------------------------
  
  #------------------------------------------------------------------------------->
  #Observa se o botão para iniciar foi pressionado e exibe um Modal
  observeEvent(input$inicio, {
    shinyalert("Sucesso!", "Agora clique na aba 'PREVISÃO'", type = "success")
  })
  #<-------------------------------------------------------------------------------
  
  #------------------------------------------------------------------------------->
  #Parte onde é criada, treinada e exibida a rede neural e a tabela de predições
  output$rede_neural <- DT::renderDataTable({
    if(is.null(input$inicio) || input$inicio == 0){
      return(NULL)
    }
    
    library(shinyalert)
    #Se o botão iniciar for clicado
    if(input$inicio > 0){
      withProgress(message="Processando o Arquivo!", value=0.1, {
        #Lendo os dados
        dS <- import(input$file1$datapath)
        #Recebe os nomes das colunas do dataset
        nomesdS <- names(dS)
        #Colunas NA recebem o valor 0
        dS[is.na(dS)] = 0
        
        #Retira espaços e caracteres especiais do nome da classe, pois o R não os reconhece
        removeChardS <- function(str) {
          str = str_replace_all(str, fixed(" "),"")
          str = str_replace_all(str, fixed("("),"")
          str = str_replace_all(str, fixed(")"),"")
          str = str_replace_all(str, fixed("-"),"")
          str = str_replace_all(str, fixed("[áàãâä]"),"a")
          str = str_replace_all(str, fixed("[éèêë]"),"e")
          str = str_replace_all(str, fixed("[íìîï]"), "i")
          str = str_replace_all(str, fixed("[óòõôö]"), "o")
          str = str_replace_all(str, fixed("[úùûü]"), "u")
          str = str_replace_all(str, fixed("ç"), "c")
          str = str_replace_all(str, fixed("[,(),;:|!#$%&/=?~^><ªº-]"), "")
          str = str_replace_all(str, fixed("[^a-z0-9]"), "")
          str = str_replace_all(str, fixed("_+/"), "")
          
          return(str);
        }
        #Atribui os nomes novos das colunas ao dataset
        names(dS) <- removeChardS(nomesdS)
      
        #Função para normalizar o dataset
        normalize <- function(x) {
          z = x
          if(min(x) < max(x)){ 
            z = (x - min(x)) / (max(x) - min(x))
          }
          return(z)
        }
        
        #Normalização do dataset. Valores ficam na dimens?o entre 0 e 1
        dataset <- as.data.frame(lapply(dS, normalize))
        
        #Criando a fórmula que pega os nomes das colunas e concatena cada um com o símbolo '+'
        formula = str_c(input$atributos[1:length(input$atributos)],
                        collapse = "+");
        
        #Barra para exibir o progresso
        incProgress(0.2, detail = "Analisando os Dados");
        
        #Separação de dados do dataset, parte para treino e parte teste
        index = sample(seq_len(nrow(dataset)), size = 0.90 * nrow(dataset))
        treino <<- dataset[ index, ];
        teste <<- dataset[ -index, ];
        
        #Desnormalizando os dados de teste
        #testeDesnorm <- (teste) * (max(dataset) - min(dataset)) + min(dataset)
        #testeCDesnorm <- (teste[, input$classe]) * (max(dataset[, input$classe]) - min(dataset[, input$classe])) + min(dataset[, input$classe])
        testeCDesnorm <- data.frame(min(dS[, input$classe]) + teste[, input$classe] * (max(dS[, input$classe]) - min(dS[, input$classe])))
        testeDesnorm <- data.frame(min(dS) + teste * (max(dS) - min(dS)))  
        
        incProgress(0.2, detail ="Criando o Modelo");
        
        #Aplicando a Rede Neural  
        NN = neuralnet(
                str_c(input$classe, " ~ ", formula), treino,
                algorithm = "rprop+", startweights = NULL,
                hidden = c(5, 2), stepmax = 1e+06,
                lifesign = "none", threshold = 0.01,
             );
        
        #Progresso do Teste
        incProgress(0.5, detail = "Testando os Dados")
        
        #Resultados
        previsao = compute(NN, teste);
        
        #C?lculo de Precisão
        precisao <- ((1 - (abs(mean((previsao$net.result - teste[2, input$classe]) / previsao$net.result)))) * 100)
        
        #Desnormalizando os valores obtidos no resultado
        resultadoDesnorm <- data.frame(min(dS[, input$classe]) + previsao$net.result * (max(dS[, input$classe]) - min(dS[, input$classe])))
        
        #Colocando as predições como uma nova coluna do dataframe
        resultado <- teste[str_c("Previsão")] <<- previsao$net.result
        resultadoDesnorm <- teste[str_c("Previsão Desnormalizada")] <<- resultadoDesnorm
        
        DT::datatable(resultado, resultadoDesnorm);
        
        hr()
        output$plotLinha <- renderPlot({
          plot(cbind(testeCDesnorm, resultadoDesnorm),
                     col = 'red', cex = 2, pch = 18,
               xlab = 'Valor Real', ylab = 'Valor Predito', xlim = c(0, 30), ylim = c(0, 30))
          abline(0, 1, lwd = 2)
        })
        
        #Linha horizontal
        hr()
        
        #PLot da Rede Neural
        output$plot <- renderPlot({
          #pdf("test.pdf")
          plot.nnet(NN)
          #dev.off()
        })
          
        #Possibilita fazer o download dos Resultados
        output$visao <- renderUI({
          return(
            div(
              h4(strong("Erro de Treino (SSE): "), NN$result.matrix[1,], align = "center"),
              #h4(strong("Erro: "), MSE.lm, align = "center"),
              h4(strong("Erro de Teste (MSE): "), sum((teste[2, input$classe] - previsao$net.result)^2)/nrow(teste), align = "center"),
              #sum((testeCDesnorm - resultadoDesnorm)^2)/nrow(testeDesnorm)
              h4(strong("Número de Iterações: "), NN$result.matrix[3], align = "center"),
              h4(strong("Precisão: "), str_c(precisao,"%"), align = "center"),
              br(),
              hr(),
              #output$matrizC <- renderTable ({
                #h4(strong("Matriz de Confusão: "), align = "center")
              #}),
              br(),
              h3(strong("Download:"), align = "center"),
              div(downloadButton('download', 'Download do Resultado'), align = "center"),
              br()
            ) #Fim da div()
          );
        })
        return(teste)
      })
    }
  }) #Fim output$rede_neural
  #<-------------------------------------------------------------------------------
  
  #------------------------------------------------------------------------------->
  #Download do .csv com os resultados
  output$download <- downloadHandler(
    filename = function(){
      str_c("redeNeural_", Sys.Date(), ".csv", sep="")
    },
    content = function(file){
      write.csv(teste, file)
    }
  ) #Fim do output$download
  #<-------------------------------------------------------------------------------
  
  #------------------------------------------------------------------------------->
  #Início da aba AJUDA
  #Sobre
  output$sobre <- renderUI(
    div(
      #h3(strong("Preditor de Paleotemperaturas")),
      #br(),
      h4(strong("Criado por:"), align = "center"),
      h4("Marinara Rübenich Fumagalli", align = "center"),
      h4(strong("Orientador:"), align = "center"),
      h4("Joaquim Vinícius Carvalho Assunção", align = "center"),
      br(),
      h5("Esta aplicação web foi criada com muita dedicação, como base para o meu Trabalho de Graduação (TG),
      com intuito de que seja útil a todos os que possam se interessar", align = "center"),
      br(),
      h4(strong("Título do TG: "), align = "center"),
      h4("Aplicação de Redes Neurais para estimativa de temperaturas
          com base em amostras de foraminíferos", align = "center"),
      h5(strong("Trabalho de Graduação do Curso de bacharelado em Sistemas de Informação - UFSM"), align = "center"),
      br(),
      br(),
      br(),
      h4(strong("Data Início: "),"11/03/2019", align = "center"),
      h4(strong("Data Fim:"), "08/07/2019", align = "center"),
      br()
    )
  )#Fim do outpu$sobre
  
  #Manual
  #output$exemplo <- renderDataTable(
    #h3(strong("Download:"), align = "center"),
    #div(downloadButton('download', 'Download do Resultado'), align = "center"),
    #br(),
    #url <- 'https://docs.google.com/spreadsheets/d/1XAlS_JxUCpWjh5InGT-_BjLLCsVj5f5Vus5sWViVZeM/',
    #a <- gsheet2text(url, format='csv'),
    #b <- read.csv(a, stringsAsFactors=FALSE),
    #data.frame(b)
  #)#Fim do outpu$manual
  
  #Manual
  output$manual <- renderUI(
    div(
      h2(strong("Esclarecimentos sobre como utilizar a aplicação:"), align = "center"),
      h1(strong("EM BREVE..."), align = "center")
    )
  )#Fim do outpu$manual
  
  #Resultados
  output$resultados <- renderUI(
    div(
      h2(strong("Esclarecimentos sobre os Resultados apresentados:"), align = "center"),
      h1(strong("EM BREVE..."), align = "center")
    )
  )#Fim do outpu$resultado
  #FIM da aba AJUDA
  #<-------------------------------------------------------------------------------
  
  #------------------------------------------------------------------------------->
  #Download do .csv de Exemplo
  output$downloadData <- downloadHandler(
    #filename = function(){
      #paste("exemplo_RNA-fora.csv", ".csv", sep="")
    #},
    #content = function(file){
      #write.csv(a, file)
    #}
  ) #Fim do output$DownloadData
  #<-------------------------------------------------------------------------------
  
  #------------------------------------------------------------------------------->
  #Início da aba CONTATO
  output$contato <- renderUI(
    div(
      #h3(strong("Preditor de Paleotemperaturas")),
      #br(),
      h4(strong("Criado por:"), align = "center"),
      h4("Marinara Rübenich Fumagalli", align = "center"),
      br(),
      h4(strong("E-mails:"), align = "center"),
      h4("mrfumagalli@inf.ufsm.br", align = "center"),
      h4("marinararubenich@gmail.com", align = "center"),
      h4(strong("Telefone/WhatsApp:"), align = "center"),
      h4("(55) 9 9648-6140", align = "center"),
      br(),
      br(),
      br(),
      h4(strong("Cidade:"), align = "center"),
      h4("Júlio de Castilhos/RS", align = "center"),
      br()
    )
  )#Fim do outpu$contato
  #<-------------------------------------------------------------------------------
}) #Fim