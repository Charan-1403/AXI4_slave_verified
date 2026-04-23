# AXI4 Full-Duplex Slave Memory Controller

### *From-Scratch RTL Design and SystemVerilog Verification*

---

## **Overview**

This project presents a *ground-up implementation* of an **AMBA AXI4 slave memory controller**, written entirely in SystemVerilog. The design supports all major AXI4 transaction types — **FIXED**, **INCR**, and **WRAP** bursts — while correctly handling:

* Misaligned memory accesses
* Byte-lane selective writes using **WSTRB**
* Back-to-back burst transactions
* Full-duplex read/write operation

The slave is *strictly compliant* with the AXI4 protocol, with the exception of a few non-critical features such as `AxCACHE`, `AxPROT`, and slave error responses. Aside from these, the core datapath and control logic are fully functional and verified.

The design is **parameterized**, allowing scalability across different data widths and configurations.

---

## **Architectural Inspiration**

The architecture is heavily inspired by the work of Dan Gisselquist, particularly his article *“Building the Perfect AXI4 Slave.”*

A key takeaway from this work is that a high-performance AXI slave must go beyond correctness — it must sustain **continuous throughput without pipeline bubbles**, even under backpressure.

To achieve this, the design adopts a **skid buffer-based pipeline architecture**, which:

* Eliminates combinational dependencies between `VALID` and `READY`
* Provides *elastic buffering* between pipeline stages
* Enables *back-to-back transaction acceptance*
* Maintains *near-constant throughput* under varying load

This ensures strict adherence to the AXI rule:

> *A `VALID` signal must never depend on a `READY` signal.*

---

## **Design Methodology**

A major shift in this project was moving away from conventional FSM-heavy design toward a **signal-driven state representation**.

Instead of explicit state registers, the design encodes state implicitly through:

* Registered control signals
* Handshake interactions
* Internal condition flags

Over time, a consistent design loop emerged:

1. **Inventory**
   Identify signals under direct control vs externally driven signals

2. **Clear Conditions**
   Define when internal registers must reset or hold

3. **Set Conditions**
   Establish when signals should assert

4. **Optimize**
   Reduce redundancy and minimize interdependencies

This *iterative refinement loop* became central to building stable and optimized RTL.

---

## **Read Channel Design (AR → R)**

The read path was implemented first and served as the foundation for understanding AXI behavior at a deeper level.

### *Baseline Construction*

Development began with an idealized scenario:

* No overlapping transactions
* No backpressure
* A master always ready to accept data

This “utopian” model established a clean baseline for signal interactions.

### *Edge Case Integration*

Complexity was introduced incrementally:

* Overlapping bursts
* Delayed `READY` signals
* Misaligned accesses

A key challenge was ensuring that modifications for one condition did not destabilize another.

For instance, a single register such as `rlen` influences both:

* `rlast` generation
* `arready` assertion

Any change required *cross-verification across multiple dependent signals*.

---

### **Address Generation and Alignment**

#### *INCR Bursts*

Address increments dynamically based on `ARSIZE`.

#### *WRAP Bursts*

Addresses must wrap within a boundary defined by:

```
Boundary = Burst_Length × Transfer_Size
```

Efficient implementation required **bit masking techniques**, avoiding expensive arithmetic logic.

---

### **Misaligned Access and Byte-Lane Handling**

The design correctly handles narrow and misaligned transfers by:

* Activating only the required byte lanes
* Masking or preserving inactive portions of the data bus

This is achieved through a combination of:

* Address alignment logic
* Byte masking derived from `WSTRB`

---

## **Verification Strategy (Mini-UVM Approach)**

Given the protocol complexity, a traditional Verilog testbench was insufficient. A **SystemVerilog-based verification environment** was developed, inspired by UVM principles.

### **Testbench Architecture**

The environment consists of:

* *Transaction class* (`axi_transaction`)
* *Generator* (stimulus creation)
* *Driver* (pin-level execution)
* *Monitor* (signal observation)
* *Scoreboard* (data verification)
* *Environment* (integration layer)

All components operate concurrently using `fork-join` constructs, with communication handled through **parameterized mailboxes**.

---

### **Constrained Random Testing**

Stimulus generation follows AXI constraints:

* `AxSIZE` does not exceed data bus width
* Addresses remain within valid boundaries (e.g., 4 MiB region)
* Burst configurations follow AXI rules

Queues are used within the monitor and scoreboard to:

* Capture DUT responses
* Perform end-to-end data validation

This phase also involved practical exposure to:

* Object randomization (`rand`, `.randomize()`)
* Assertions
* Basic coverage constructs

---

## **Write Channel Design (AW → W → B)**

The write path follows a **three-stage pipeline architecture** rather than a conventional FSM:

1. Address intake (AW)
2. Data processing (W)
3. Response generation (B)

Each stage is decoupled using **skid buffers**, ensuring stable data flow and proper backpressure handling.

Interestingly, the write channel proved conceptually simpler than the read channel, as many critical signals are *inputs* rather than outputs. This shifts the problem from coordination to *handling incoming behavior*.

---

### **Pipeline Intuition: The Barista Analogy**

To reason about the pipeline, the following analogy proved extremely effective.

Consider a coffee shop:

* The **barista** represents the core processing stage (W channel)
* The **input counter** represents the AW skid buffer
* The **output counter** represents the B skid buffer
* A **signboard** above the barista indicates whether she is accepting orders (`READY`)

Customers bring cups (address requests). If the barista is accepting orders, the cup is handed directly to her. Otherwise, it is placed on the input counter, modeling backpressure.

The barista follows one strict rule:

> *She only accepts a new order if the output counter is empty, or guaranteed to be cleared in the next cycle.*

If this condition is not met, she stops accepting new cups.

This rule ensures:

* No overflow of pending work
* Clean propagation of backpressure
* Stable pipeline behavior across all stages

Mapping this back to RTL:

* Each stage only accepts new data when downstream stages are ready
* Backpressure propagates from output to input naturally
* The pipeline remains stable without explicit global control

This analogy significantly simplified reasoning about the interaction between AW, W, and B channels.

---

## **System Integration and Testing**

After implementing both read and write paths, the testbench was extended to support:

* *Read-after-write validation*
* *Simultaneous full-duplex transactions*

Stress testing included:

* Back-to-back burst sequences
* Randomized transaction streams
* Variable backpressure scenarios

These tests confirmed that both channels operate independently and reliably under load.

---

## **Results**

The final design demonstrates:

* Correct implementation of all AXI4 burst types
* Robust handling of misaligned and narrow transfers
* Accurate byte-lane control using `WSTRB`
* Stable operation under backpressure
* Independent full-duplex read/write operation
* High-throughput behavior with minimal pipeline stalls

---

## **Future Work**

Potential extensions include:

* Improving timing to support higher clock frequencies
* Adding support for `AxCACHE`, `AxPROT`, and error responses
* Migrating the verification environment to full UVM
* Expanding coverage to systematically explore all deadlock scenarios

---

## **Closing Remarks**

This project evolved from a protocol implementation into a deeper exercise in **hardware design thinking**.

It required careful reasoning about:

* Timing
* Concurrency
* Signal dependencies
* Edge-case stability
