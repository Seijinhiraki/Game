<!DOCTYPE html>
<html lang="pt-br">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Jogo de Compras</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      text-align: center;
      background-color: #f4f4f4;
      margin: 0;
      padding: 0;
    }
    #game-container {
      margin-top: 20px;
    }
    #money {
      font-size: 24px;
      color: green;
      margin-bottom: 20px;
    }
    #timer {
      position: absolute;
      top: 10px;
      right: 10px;
      font-size: 20px;
      color: orange;
    }
    #message {
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      background-color: rgba(0, 0, 0, 0.7);
      color: white;
      padding: 10px 20px;
      border-radius: 5px;
      font-size: 18px;
      display: none;
      z-index: 1000;
    }
    .item {
      margin: 10px 0;
      padding: 10px;
      border: 1px solid black;
      display: inline-block;
      background-color: white;
      cursor: pointer;
    }
    .item:hover {
      background-color: lightblue;
    }
    .button-container {
      position: fixed;
      bottom: 0;
      width: 100%;
      background-color: white;
      padding: 10px;
      box-shadow: 0 -2px 5px rgba(0, 0, 0, 0.1);
      display: flex;
      justify-content: space-around;
    }
    .button {
      margin: 10px;
      padding: 10px 20px;
      font-size: 18px;
      cursor: pointer;
    }
    .inventory, .store, .status {
      display: none;
      max-height: calc(100vh - 150px); /* Altura máxima ajustável */
      overflow-y: auto; /* Adiciona barra de rolagem vertical */
      padding: 10px;
    }
    .active {
      display: block;
    }
    #hunger-bar {
      width: 80%;
      height: 20px;
      background-color: lightgray;
      margin: 20px auto;
      position: relative;
      border: 1px solid black;
    }
    #hunger-fill {
      height: 100%;
      background-color: green;
      transition: width 0.5s;
    }
    #hunger-text {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      text-align: center;
      line-height: 20px;
      color: white;
      font-weight: bold;
    }
    #item-details {
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      background-color: white;
      padding: 20px;
      border: 1px solid black;
      box-shadow: 0 0 10px rgba(0, 0, 0, 0.2);
      display: none;
      z-index: 1000;
    }
    #item-use-prompt {
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      background-color: white;
      padding: 20px;
      border: 1px solid black;
      box-shadow: 0 0 10px rgba(0, 0, 0, 0.2);
      display: none;
      z-index: 1000;
    }
  </style>
</head>
<body>
  <div id="game-container">
    <div id="money">Dinheiro: R$ 1000</div>
    <div id="timer">💰(5)</div>
    <div id="message"></div>
    <div id="status" class="status">
      <h2>Status</h2>
      <div id="player-name">
        Nome: <span id="name-display">Não Definido</span>
        <button id="set-name-btn" onclick="setName()">Definir Nome</button>
      </div>
      <div>Conta Bancária: <span id="bank-account">R$ 1000</span></div>
      <div id="hunger-bar">
        <div id="hunger-fill" style="width: 100%;"></div>
        <div id="hunger-text">Fome: 100%</div>
      </div>
      <button id="work-btn" onclick="startWork()">Trabalho</button>
    </div>
    <div id="inventory" class="inventory active">
      <h2>Inventário</h2>
      <div id="owned-items"></div>
    </div>
    <div id="store" class="store">
      <h2>Loja</h2>
      <div id="store-items"></div>
    </div>
    <div id="item-details">
      <div id="item-icon" style="font-size: 40px;"></div>
      <div id="item-name"></div>
      <div id="item-price"></div>
      <div id="item-hunger"></div>
      <button id="buy-item-btn" onclick="buySelectedItem()">Comprar</button>
      <button onclick="closeItemDetails()">Fechar</button>
    </div>
    <div id="item-use-prompt">
      <p>Deseja usar este item?</p>
      <p><strong>Nome:</strong> <span id="use-item-name"></span></p>
      <p><strong>Efeito:</strong> <span id="use-item-effect"></span></p>
      <button onclick="useSelectedItem()">Sim</button>
      <button onclick="closeUsePrompt()">Não</button>
    </div>
  </div>
  <div class="button-container">
    <button class="button" onclick="toggleView('status')">Status</button>
    <button class="button" onclick="toggleView('inventory')">Inventário</button>
    <button class="button" onclick="toggleView('store')">Loja</button>
  </div>
  <script>
    let money = 1000;
    const incomePerCycle = 10;
    const cycleTime = 5; // Tempo em segundos
    let timer = cycleTime;
    let hunger = 100; // Porcentagem de fome
    const hungerDecreaseRate = 100 / (5 * 60); // 5 minutos para chegar a 0%
    let playerName = "Não Definido";
    let isNameSet = false;
    const ownedItems = {};
    const storeItems = {
      food: [
        { name: "Banana", price: 5, hungerRestore: 10, icon: "🍌" },
        { name: "Pão", price: 10, hungerRestore: 5, icon: "🍞" },
        { name: "Batata", price: 15, hungerRestore: 15, icon: "🥔" },
        { name: "Prato Pronto", price: 25, hungerRestore: 70, icon: "🍽️" }
      ],
      cars: [
        { name: "Moto", price: 15000, icon: "🏍️" },
        { name: "Carro Normal", price: 50000, icon: "🚗" },
        { name: "Carro Esportivo", price: 100000, icon: "🏎️" }
      ],
      houses: [
        { name: "Casa Pequena", price: 10000, icon: "🏠" },
        { name: "Casa Média", price: 50000, icon: "🏡" },
        { name: "Casa Grande", price: 100000, icon: "🏢" },
        { name: "Mansão", price: 500000, icon: "🏰" }
      ]
    };
    let selectedItem = null;

    // Variável para controlar se o jogador está trabalhando
    let isWorking = false;

    function updateMoneyDisplay() {
      document.getElementById("money").innerText = `Dinheiro: R$ ${money}`;
      document.getElementById("bank-account").innerText = `R$ ${money}`;
    }

    function showMessage(message) {
      const messageDiv = document.getElementById("message");
      messageDiv.innerText = message;
      messageDiv.style.display = "block";
      setTimeout(() => {
        messageDiv.style.display = "none";
      }, 2000); // A mensagem desaparece após 2 segundos
    }

    function setName() {
      if (!isNameSet) {
        const name = prompt("Digite seu nome:");
        if (name) {
          playerName = name;
          isNameSet = true;
          document.getElementById("name-display").innerText = playerName;
          document.getElementById("set-name-btn").innerText = "Trocar Nome";
          showMessage("Nome definido com sucesso!");
        }
      } else {
        if (confirm("Alterar o nome custa R$ 10.000. Deseja continuar?")) {
          if (money >= 10000) {
            money -= 10000;
            const name = prompt("Digite seu novo nome:");
            if (name) {
              playerName = name;
              document.getElementById("name-display").innerText = playerName;
              showMessage("Nome alterado com sucesso!");
            }
            updateMoneyDisplay();
          } else {
            showMessage("Dinheiro insuficiente para alterar o nome!");
          }
        }
      }
    }

    function updateHunger() {
      hunger = Math.max(0, hunger - hungerDecreaseRate);
      document.getElementById("hunger-fill").style.width = `${hunger}%`;
      document.getElementById("hunger-text").innerText = `Fome: ${Math.round(hunger)}%`;
    }

    function eatFood(item) {
      hunger = Math.min(100, hunger + item.hungerRestore);
      document.getElementById("hunger-fill").style.width = `${hunger}%`;
      document.getElementById("hunger-text").innerText = `Fome: ${Math.round(hunger)}%`;
      showMessage(`Você comeu ${item.name} e restaurou ${item.hungerRestore}% de fome.`);
    }

    function addItemToInventory(item) {
      if (!ownedItems[item.name]) {
        ownedItems[item.name] = { ...item, quantity: 1 };
      } else {
        ownedItems[item.name].quantity++;
      }
      updateInventoryDisplay();
    }

    function removeItemFromInventory(itemName) {
      if (ownedItems[itemName]) {
        if (ownedItems[itemName].quantity > 1) {
          ownedItems[itemName].quantity--;
        } else {
          delete ownedItems[itemName];
        }
        updateInventoryDisplay();
      }
    }

    function updateInventoryDisplay() {
      const inventoryDiv = document.getElementById("owned-items");
      inventoryDiv.innerHTML = "<h3>Itens no Inventário:</h3>";
      for (const itemName in ownedItems) {
        const item = ownedItems[itemName];
        const itemDiv = document.createElement("div");
        itemDiv.className = getCategoryClass(item);
        itemDiv.innerText = `${item.icon} ${item.name} x${item.quantity}`;
        itemDiv.onclick = () => showUsePrompt(item);
        inventoryDiv.appendChild(itemDiv);
      }
    }

    function renderStoreItems() {
      const storeItemsDiv = document.getElementById("store-items");
      storeItemsDiv.innerHTML = "";
      // Renderizar comida
      storeItemsDiv.appendChild(createCategoryHeader("Comida"));
      storeItems.food.forEach(item => {
        storeItemsDiv.appendChild(createStoreItemElement(item));
      });
      // Renderizar carros
      storeItemsDiv.appendChild(createCategoryHeader("Carros"));
      storeItems.cars.forEach(item => {
        storeItemsDiv.appendChild(createStoreItemElement(item));
      });
      // Renderizar casas
      storeItemsDiv.appendChild(createCategoryHeader("Casas"));
      storeItems.houses.forEach(item => {
        storeItemsDiv.appendChild(createStoreItemElement(item));
      });
    }

    function createCategoryHeader(categoryName) {
      const header = document.createElement("div");
      header.className = "category";
      header.innerText = categoryName;
      return header;
    }

    function createStoreItemElement(item) {
      const itemDiv = document.createElement("div");
      itemDiv.className = `item ${getCategoryClass(item)}`;
      itemDiv.innerHTML = `${item.icon} ${item.name} - R$ ${item.price}`;
      itemDiv.onclick = () => showItemDetails(item);
      return itemDiv;
    }

    function getCategoryClass(item) {
      if (storeItems.food.some(food => food.name === item.name)) return "food";
      if (storeItems.cars.some(car => car.name === item.name)) return "car";
      if (storeItems.houses.some(house => house.name === item.name)) return "house";
      return "";
    }

    function showItemDetails(item) {
      selectedItem = item;
      document.getElementById("item-icon").innerText = item.icon;
      document.getElementById("item-name").innerText = `Nome: ${item.name}`;
      document.getElementById("item-price").innerText = `Preço: R$ ${item.price}`;
      document.getElementById("item-hunger").innerText = item.hungerRestore ? `Restaura Fome: ${item.hungerRestore}%` : "";
      document.getElementById("item-details").style.display = "block";
    }

    function closeItemDetails() {
      document.getElementById("item-details").style.display = "none";
      selectedItem = null;
    }

    function buySelectedItem() {
      if (selectedItem && money >= selectedItem.price) {
        money -= selectedItem.price;
        addItemToInventory(selectedItem);
        updateMoneyDisplay();
        showMessage(`Você comprou ${selectedItem.name} por R$ ${selectedItem.price}`);
        closeItemDetails();
      } else {
        showMessage("Dinheiro insuficiente!");
      }
    }

    function showUsePrompt(item) {
      document.getElementById("use-item-name").innerText = item.name;
      document.getElementById("use-item-effect").innerText = item.hungerRestore
        ? `Restaura ${item.hungerRestore}% de fome`
        : "Este item não tem efeito.";
      selectedItem = item;
      document.getElementById("item-use-prompt").style.display = "block";
    }

    function closeUsePrompt() {
      document.getElementById("item-use-prompt").style.display = "none";
      selectedItem = null;
    }

    function useSelectedItem() {
      if (selectedItem) {
        if (selectedItem.hungerRestore) {
          eatFood(selectedItem);
        }
        removeItemFromInventory(selectedItem.name);
        showMessage(`Você usou ${selectedItem.name}.`);
        closeUsePrompt();
      }
    }

    function toggleView(view) {
      document.getElementById("status").classList.toggle("active", view === "status");
      document.getElementById("inventory").classList.toggle("active", view === "inventory");
      document.getElementById("store").classList.toggle("active", view === "store");
    }

    function updateTimer() {
      timer--;
      document.getElementById("timer").innerText = `💰(${timer})`;
      if (timer <= 0) {
        money += incomePerCycle;
        updateMoneyDisplay();
        timer = cycleTime;
      }
    }

    setInterval(updateTimer, 1000);
    setInterval(updateHunger, 1000);
    renderStoreItems();
    updateMoneyDisplay();

    // Função do minigame de matemática
    function startWork() {
      if (isWorking) return;

      isWorking = true;
      const workButton = document.getElementById("work-btn");
      workButton.disabled = true;
      workButton.innerText = "Trabalhando...";

      const mathOperations = ['+', '-', '/'];
      const questions = [];
      let correctAnswers = 0;
      let totalQuestions = 5;

      // Gerar perguntas aleatórias
      for (let i = 0; i < totalQuestions; i++) {
        const num1 = Math.floor(Math.random() * 20) + 1;
        const num2 = Math.floor(Math.random() * 20) + 1;
        const operation = mathOperations[Math.floor(Math.random() * mathOperations.length)];

        let answer;
        switch (operation) {
          case '+':
            answer = num1 + num2;
            break;
          case '-':
            answer = num1 - num2;
            break;
          case '/':
            // Garantir que a divisão seja exata
            const product = num1 * num2;
            answer = product / num2;
            num1 = product;
            break;
        }

        questions.push({
          question: `${num1} ${operation} ${num2}`,
          answer: answer
        });
      }

      let currentQuestion = 0;

      function askQuestion() {
        if (currentQuestion >= totalQuestions) {
          endQuiz();
          return;
        }

        const question = questions[currentQuestion];
        const userAnswer = prompt(`Pergunta ${currentQuestion + 1}/${totalQuestions}:\nQuanto é ${question.question}?`);

        if (userAnswer !== null && !isNaN(userAnswer)) {
          if (parseFloat(userAnswer) === question.answer) {
            correctAnswers++;
          }
        }

        currentQuestion++;
        askQuestion();
      }

      function endQuiz() {
        if (correctAnswers >= totalQuestions / 2) {
          money += 10000; // Recompensa de 10 mil
          updateMoneyDisplay();
          showMessage("Você concluiu o trabalho com sucesso! Recebeu R$ 10.000.");
        } else {
          showMessage("Você não acertou o suficiente para receber a recompensa.");
        }

        // Aguardar 30 segundos antes de permitir trabalhar novamente
        setTimeout(() => {
          isWorking = false;
          workButton.disabled = false;
          workButton.innerText = "Trabalho";
        }, 30000);
      }

      askQuestion();
    }
  </script>
</body>
</html>
