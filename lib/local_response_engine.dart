class LocalResponseContext {
  const LocalResponseContext({
    required this.ownerName,
    required this.businessName,
    required this.sales,
    required this.operations,
    required this.expectedCash,
    required this.lowStock,
    required this.topProduct,
    required this.shoppingItems,
    required this.dayClosed,
  });

  final String ownerName;
  final String businessName;
  final String sales;
  final int operations;
  final String expectedCash;
  final List<String> lowStock;
  final String topProduct;
  final int shoppingItems;
  final bool dayClosed;
}

class LocalResponseEngine {
  const LocalResponseEngine();

  String reply(String input, LocalResponseContext data) {
    final text = _normalize(input);

    if (_matches(text, ["hola", "buenos dias", "buenas tardes"])) {
      return "Hola, ${data.ownerName}. Tengo listos los datos locales de "
          "${data.businessName}. Puedes preguntarme por ventas, caja, "
          "inventario, productos bajos o el cierre.";
    }
    if (_matches(text, ["ayuda", "que puedes", "comandos", "opciones"])) {
      return "Puedo registrar ventas escritas y responder sobre ventas de hoy, "
          "caja, inventario, productos con stock bajo, producto más vendido, "
          "lista de compra y cierre del día.";
    }
    if (_matches(text, ["como va", "resumen", "negocio hoy", "estado"])) {
      return "${data.businessName} lleva ${data.sales} en "
          "${data.operations} operaciones. El efectivo esperado es "
          "${data.expectedCash}. ${_stockSentence(data.lowStock)}";
    }
    if (_matches(
      text,
      ["venta", "ventas", "vendi", "vendido", "ingreso", "facturacion"],
    )) {
      return "Hoy registraste ${data.operations} operaciones por un total de "
          "${data.sales}. El producto con mayor movimiento es "
          "${data.topProduct}.";
    }
    if (_matches(text, ["caja", "efectivo", "dinero contado"])) {
      return "El efectivo esperado en caja es ${data.expectedCash}. "
          "${data.dayClosed ? "El cierre de hoy ya está guardado." : "El día sigue abierto; puedes preparar el cierre desde Inicio o Hoy."}";
    }
    if (_matches(text, ["falta", "stock", "inventario", "agotar", "reponer"])) {
      return _stockSentence(data.lowStock);
    }
    if (_matches(text, ["mas vendido", "mejor producto", "producto lider"])) {
      return "El producto con mayor movimiento hoy es ${data.topProduct}.";
    }
    if (_matches(text, ["compra", "pedido", "proveedor"])) {
      return "Tu lista de compra tiene ${data.shoppingItems} productos. "
          "Puedes editar cantidades y copiarla desde la sección Negocio.";
    }
    if (_matches(text, ["cerrar", "cierre", "terminar dia"])) {
      return data.dayClosed
          ? "El cierre de hoy ya está guardado en la memoria local."
          : "El día todavía está abierto. Entra a Hoy y toca “Preparar el cierre del día” para contar el efectivo.";
    }
    if (_matches(text, ["gracias", "perfecto", "listo"])) {
      return "Listo. Todos los cambios quedan guardados localmente en este dispositivo.";
    }

    return "No tengo una respuesta fija para esa frase todavía. Prueba con: "
        "“¿Cómo va el negocio?”, “¿Qué falta?”, “¿Cuánto hay en caja?” o "
        "“Ayuda”. También puedes registrar una venta, por ejemplo: "
        "“Vendí dos tomates y una lechuga”.";
  }

  String _stockSentence(List<String> products) {
    if (products.isEmpty) return "El inventario no tiene alertas de stock.";
    return "Necesitan reposición: ${products.join(", ")}.";
  }

  bool _matches(String text, List<String> patterns) =>
      patterns.any(text.contains);

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll("á", "a")
      .replaceAll("é", "e")
      .replaceAll("í", "i")
      .replaceAll("ó", "o")
      .replaceAll("ú", "u")
      .replaceAll("¿", "")
      .replaceAll("?", "");
}
