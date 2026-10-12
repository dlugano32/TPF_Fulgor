from model.python.src.prbs31 import ORDER, PRBS31Generator


class PRBS31Checker:
    """Checker que recupera el estado inicial desde los bits recibidos."""

    def __init__(self, taps: list[int], lock_matches: int = 1):
        if lock_matches <= 0:
            raise ValueError("La cantidad de coincidencias debe ser mayor que cero")

        if not taps or any(tap < 0 or tap >= ORDER for tap in taps):
            raise ValueError("Cada tap debe ser un índice válido del estado")

        if len(set(taps)) != len(taps):
            raise ValueError("Los taps no pueden estar repetidos")

        self.history_indices = [ORDER - 1 - tap for tap in taps]
        self.lock_matches = lock_matches
        self.reset()

    def reset(self) -> None:
        """Limpia el estado y los contadores del checker."""

        self.history = []
        self.consecutive_matches = 0
        self.locked = False
        self.received_bits = 0
        self.discarded_bits = 0
        self.checked_bits = 0
        self.error_bits = 0

    def check_bit(self, received: int) -> None:
        """Procesa un bit recibido y actualiza el estado del checker."""

        if received not in (0, 1):
            raise ValueError("Cada bit recibido debe valer cero o uno")

        self.received_bits += 1

        if len(self.history) < ORDER:
            self.history.append(received)
            return

        expected = 0

        for history_index in self.history_indices:
            expected ^= self.history[history_index]

        if not self.locked:
            if received == expected and any(self.history):
                self.consecutive_matches += 1
            else:
                self.consecutive_matches = 0

            self.history.pop(0)
            self.history.append(received)

            if self.consecutive_matches == self.lock_matches:
                self.locked = True
                self.discarded_bits = self.received_bits

            return

        self.checked_bits += 1

        if received != expected:
            self.error_bits += 1

        # Una vez adquirido el lock, la referencia avanza con el bit esperado
        # y no con el recibido. Así cada error del canal se cuenta una sola vez.
        self.history.pop(0)
        self.history.append(expected)

    def check(self, received_bits: list[int]) -> None:
        """Procesa una secuencia de bits en orden temporal."""

        for received in received_bits:
            self.check_bit(received)

    def ber(self) -> float:
        """Devuelve la BER medida luego de adquirir el lock."""

        if self.checked_bits == 0:
            return 0.0

        return self.error_bits / self.checked_bits


def main() -> None:
    taps = [30, 27]
    transmitted_seed = 0x5A17C3D2
    transmitted_bits = PRBS31Generator(transmitted_seed, taps).generate(10_000)

    # El checker recibe solamente la secuencia, no la seed del transmisor.
    checker = PRBS31Checker(taps=taps, lock_matches=31)
    checker.check(transmitted_bits)

    assert checker.locked
    assert checker.discarded_bits == 62
    assert checker.checked_bits == len(transmitted_bits) - 62
    assert checker.error_bits == 0
    assert checker.ber() == 0.0

    print("PRBS31 checker")
    print(f"Bits recibidos  : {checker.received_bits}")
    print(f"Bits descartados: {checker.discarded_bits}")
    print(f"Bits verificados: {checker.checked_bits}")
    print(f"Errores         : {checker.error_bits}")
    print(f"BER             : {checker.ber():.3e}")
    print("Lock desde una seed desconocida: OK")


if __name__ == "__main__":
    main()
