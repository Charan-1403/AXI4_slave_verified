package axi_pkg;
    
    class axi_trans;
    
        typedef enum {READ_ONLY, WRITE_ONLY, SIMUL} axi_trans_type;
        axi_trans_type trans_type = SIMUL;
        
        rand bit[15:0] arid;
        rand bit[31:0] araddr;
        rand bit[7:0] arlen;
        rand bit[2:0] arsize;
        rand bit[1:0] arburst;
        
        logic arvalid;
        logic rready;
        
        rand bit[15:0] awid;
        rand bit[31:0] awaddr;
        rand bit[7:0]  awlen;
        rand bit[2:0]  awsize;
        rand bit[1:0]  awburst;
        
        logic awvalid;
        
        rand bit[63:0] wdata;
        rand bit[7:0] wstrb;
        
        logic wvalid;
        logic wlast;
        logic[1:0] bid;
        
        logic bready;
        
        event tx_done;
        logic[63:0] read_data_queue[$];
        logic[63:0] write_data_queue[$];

        constraint w_addr_aligned {(awaddr % (1 << awsize) == 0);}
        constraint w_size_id {awid < 1024;}
        constraint w_addr_bound {awaddr >= 0; (awaddr + ((awlen+1)<<awsize)) <= 1024;}
        constraint w_len_bound {awlen < 16;}
        constraint w_warp_size_bound {(awburst == 2'b10) -> (awlen inside {1, 3, 7, 15});}
        constraint w_fixed_size_bound {(awburst == 2'b00) -> (awlen >= 0 && awlen <= 15);}
        constraint w_data_width_bound {awsize == 3;}
        constraint w_reserved_awburst {(awburst != 2'b11);}
        
        
        constraint size_id {arid < 1024;}
        constraint addr_bound {araddr >= 0; (araddr + ((arlen+1)<<arsize)) <= 1024;}
        constraint len_bound {arlen < 16;}
        constraint warp_size_bound {(arburst == 2'b10) -> (arlen inside {1, 3, 7, 15});}
        constraint fixed_size_bound {(arburst == 2'b00) -> (arlen >= 0 && arlen <= 15);}
        constraint data_width_bound {arsize <= 3;}
        constraint reserved_arburst {(arburst != 2'b11);}
    endclass

    class generator;
        mailbox #(axi_trans) gen2drv_w;
        mailbox #(axi_trans) gen2drv;
        mailbox #(axi_trans) gen2scb_w;
        mailbox #(axi_trans) gen2scb;
        int n_trans;
        
        function new (mailbox #(axi_trans) g2d, mailbox #(axi_trans) g2s, mailbox #(axi_trans) g2d_w, mailbox #(axi_trans) g2s_w, input int n);
            this.gen2drv = g2d;
            this.gen2scb = g2s;
            this.gen2drv_w = g2d_w;
            this.gen2scb_w = g2s_w;
            this.n_trans = n;
        endfunction
        
        task run();
            axi_trans transac;
            int i;
            for(i = 0; i < n_trans; i = i + 1) begin
                transac = new();
                
                if(transac.randomize() == 0) $error("Transaction randomization failed!");
                else $display("Transaction randomized succesfully!");
                
                
                if(transac.trans_type == axi_trans::READ_ONLY || transac.trans_type == axi_trans::SIMUL)begin
                    gen2drv.put(transac);
                    gen2scb.put(transac);
                    $display("ARID = %h | ARADDR = %h | ARLEN = %d | ARSIZE = %d | ARBURST = %b", transac.arid, transac.araddr, transac.arlen, transac.arsize, transac.arburst);
                end
                if(transac.trans_type == axi_trans::WRITE_ONLY || transac.trans_type == axi_trans::SIMUL)begin
                    gen2drv_w.put(transac);
                    gen2scb_w.put(transac);
                    $display("AWID = %h | AWADDR = %h | AWLEN = %d | AWSIZE = %d | AWBURST = %b", transac.awid, transac.awaddr, transac.awlen, transac.awsize, transac.awburst);
                end
            end
        endtask
        
        task run_read_after_write();
            axi_trans w_transac;
            axi_trans r_transac;
            
            for(int i = 0; i < n_trans; i++) begin
                w_transac = new();
                if(w_transac.randomize() == 0) $display("[GENERATOR] Write transcation randomization failed!");
                else $display("[GENERATOR] Write transaction randomization success!");
                
                gen2drv_w.put(w_transac);
                gen2scb_w.put(w_transac);
                
                $display("[GENERATOR] Write transaction AWID = %d pushed to mailbox!",w_transac.awid);
                
                @(w_transac.tx_done);
                
                $display("[GENERATOR] Write transaction AWID = %d finished!",w_transac.awid);
                
                r_transac = new();
                
                if(r_transac.randomize() == 0) $display("[GENERATOR] Read transcation randomization failed!");
                else $display("[GENERATOR] Read transaction randomization success!");
                r_transac.araddr = w_transac.awaddr;
                r_transac.arsize = w_transac.awsize;
                r_transac.arburst = w_transac.awburst;
                r_transac.arlen = w_transac.awlen;
                r_transac.arid = w_transac.awid;
                
                gen2drv.put(r_transac);
                gen2scb.put(r_transac);
                $display("[GENERATOR] Read transaction ARID = %d pushed to mailbox!",r_transac.arid);
                
                @(r_transac.tx_done);
            end
        endtask
        
    endclass
    
    class driver;
        mailbox #(axi_trans) gen2drv;
        mailbox #(axi_trans) gen2drv_w;
        virtual axi_if vif;
        int num_transac;
        int i,j;
        
        function new (mailbox #(axi_trans) m, mailbox #(axi_trans) m_w, virtual axi_if v, input int n);
            this.gen2drv = m;
            this.gen2drv_w = m_w;
            this.vif = v;
            this.num_transac = n;
        endfunction
        int count;
        
        task run();
            fork
                run_write();
                run_read();
            join
        endtask
        
        task run_write();
            axi_trans w_transac;
            
            vif.awvalid <= 0;
            vif.wvalid <= 0;
            vif.bready <= 0;
            
            @(posedge vif.clk);
            for(j = 0; j < num_transac; j++) begin
                gen2drv_w.get(w_transac);
                
                vif.awvalid <= 1;
                vif.awid <= w_transac.awid;
                vif.awaddr <= w_transac.awaddr;
                vif.awburst <= w_transac.awburst;
                vif.awsize <= w_transac.awsize;
                vif.awlen <= w_transac.awlen;
                
                forever begin
                    @(posedge vif.clk);
                    if(vif.awready) break;
                end
                
                vif.awvalid <= 0;
                
                count = w_transac.awlen;
               while(count >= 0) begin
                   repeat($urandom_range(0,5)) @(posedge vif.clk);
                    
                   vif.wvalid <= 1;
                   vif.wdata <= w_transac.wdata + count;
                   //vif.wstrb <= (8'b1 << ($urandom_range(0,7)));
                   vif.wstrb <= 8'hFF;
                   vif.wlast <= (count == 0);
                    
                   forever begin
                       @(posedge vif.clk);
                       if(vif.wready) begin
                            w_transac.write_data_queue.push_back(vif.wdata);
                            break;
                       end
                   end
                    
                   vif.wlast <= 0;
                   vif.wvalid <= 0;
                    
                   count--;
                    
               end
                
               forever begin
                    vif.bready <= $urandom_range(0,1);
                    @(posedge vif.clk);
                    if(vif.bready && vif.bvalid) break;
               end
               
               vif.bready <= 0;
               -> w_transac.tx_done;
               
               $display("[DRIVER] Transaction from driver for address AWADDR = %d has been completed.", vif.awaddr);     
            end
        endtask
        
        task run_read();
            axi_trans transac;
            
            vif.arvalid <= 0;
            vif.rready <= 0;
            
            @(posedge vif.clk);
            for(i = 0; i < num_transac; i++) begin
                gen2drv.get(transac);
                
                
                vif.arvalid <= 1;
                vif.arid <= transac.arid;
                vif.arlen <= transac.arlen;
                vif.arburst <= transac.arburst;
                vif.arsize <= transac.arsize;
                vif.araddr <= transac.araddr;
                
                forever begin
                    @(posedge vif.clk);
                    if(vif.arready) break;
                end
                
                vif.arvalid <= 0;
                
                vif.rready <= $urandom_range(0,1);
                
                forever begin
                    
                    @(posedge vif.clk);
                    vif.rready <= $urandom_range(0,1);
                    if(vif.rready && vif.rvalid && vif.rlast) break;
                end
                
                vif.rready <= 0;
                -> transac.tx_done;
                
                $display("[DRIVER] Transaction from driver for address ARADDR = %d has been completed\nARLEN = %d | ARBURST = %b | ARSIZE = %d",transac.araddr, transac.arlen, transac.arburst, transac.arsize);
            end
            
            
        endtask 
    endclass
    
    class monitor;
        virtual axi_if vif;
        mailbox #(axi_trans) mon2scb;
        mailbox #(axi_trans) mon2scb_w;
        int num_trans;
        axi_trans obs_trans, obs_trans_w;
        int num_beats;
        
        
        covergroup axi_cg;
            cp_len: coverpoint obs_trans.arlen {
                bins single_beat = {0};
                bins short_burst = {[1:3]};
                bins long_burst = {[4:7]};
            }
            
            cp_addr: coverpoint obs_trans.araddr{
                bins min_addr = {0};
                bins low_addr = {[1:511]};
                bins high_addr = {[512:1023]};
                bins max_addr = {1024};
            }
            
        endgroup
        
        function new(mailbox #(axi_trans) m, mailbox #(axi_trans) m_w, virtual axi_if v, input int n);
            this.mon2scb = m;
            this.mon2scb_w = m_w;
            this.vif = v;
            this.num_trans = n;
            this.axi_cg = new();
        endfunction
        
        task run_read();
        
        for(int i = 0; i < num_trans; i++) begin
            obs_trans = new();
            num_beats = 0;
            forever begin
                    @(posedge vif.clk);
                    if(vif.arvalid && vif.arready) break;
                end
                
                obs_trans.araddr = vif.araddr;
                
                forever begin
                    @(posedge vif.clk);
                    if(vif.rvalid && vif.rready) begin
                        obs_trans.read_data_queue.push_back(vif.rdata);
                        obs_trans.arid = vif.rid;
                        num_beats = num_beats + 1;
                        if(vif.rlast) begin
                            obs_trans.arlen = num_beats - 1;
                            break;
                        end
                    end
                end
                
                mon2scb.put(obs_trans);
                axi_cg.sample();
        end
        endtask
        
        task run_write();
        for(int i = 0; i < num_trans; i++) begin
            obs_trans_w = new();
            forever begin
                @(posedge vif.clk);
                if(vif.awready && vif.awvalid) break;
            end
            
            forever begin
                @(posedge vif.clk);
                if(vif.wready && vif.wvalid && vif.wlast) break;
            end
            
            forever begin
                @(posedge vif.clk);
                if(vif.bready && vif.bvalid) break;
            end
            obs_trans.bid = vif.bid;
            
            mon2scb_w.put(obs_trans_w);
        end
        endtask
        
        task run();
            
                fork
                    run_read();
                    run_write();
                join
        endtask
        
        
        
    endclass
    
    class scoreboard;
        mailbox #(axi_trans) mon2scb;
        mailbox #(axi_trans) gen2scb;
        mailbox #(axi_trans) mon2scb_w;
        mailbox #(axi_trans) gen2scb_w;
        int num_trans;
        
        function new(mailbox #(axi_trans) m2s, mailbox #(axi_trans) g2s,mailbox #(axi_trans) m2s_w, mailbox #(axi_trans) g2s_w, input int n);
            this.mon2scb = m2s;
            this.gen2scb = g2s;
            this.mon2scb_w = m2s_w;
            this.gen2scb_w = g2s_w;
            this.num_trans = n;
        endfunction
        
        axi_trans sent_trans;
        axi_trans recv_trans;
        axi_trans sent_trans_w;
        axi_trans recv_trans_w;
        
        task run();
            fork
                write_run();
                read_run();
            join
        endtask
        
        task read_run();
            for(int i = 0; i < num_trans; i++) begin
                mon2scb.get(recv_trans);
                gen2scb.get(sent_trans);
                
                if(recv_trans.arid != sent_trans.arid) begin
                    $error("Wrong ARID! Expected: %h | Returned: %h", sent_trans.arid, recv_trans.arid);
                end
                else if(recv_trans.arlen != sent_trans.arlen)begin
                    $error("Wrong ARLEN! Expected: %h | Returned: %h", sent_trans.arlen, recv_trans.arlen);
                end
                else $display("[SCOREBOARD] R Transaction passed!");
                
                foreach(recv_trans.read_data_queue[idx]) begin
                    $display("[SCOREBOARD] Data read: %d", recv_trans.read_data_queue[idx]);
                end
                
            end
        endtask
        
        task write_run();
            for(int i = 0; i < num_trans; i++) begin
                mon2scb_w.get(recv_trans_w);
                gen2scb_w.get(sent_trans_w);
                
                if(recv_trans_w.bid != sent_trans_w.bid) begin
                    $error("Wrong BID! Expected: %h | Returned: %h", sent_trans_w.bid, recv_trans_w.bid);
                end
                else $display("[SCOREBOARD] W Transaction passed!");
                
                foreach(sent_trans_w.write_data_queue[idx]) begin
                    $display("[SCOREBOARD] Data written: %d", sent_trans_w.write_data_queue[idx]);
                end
            end
        endtask
        
    endclass
    
    class environment;
        driver drv;
        generator gen;
        scoreboard scb;
        monitor mon;
        mailbox #(axi_trans) gen2drv;
        mailbox #(axi_trans) gen2scb;
        mailbox #(axi_trans) mon2scb;
        mailbox #(axi_trans) gen2drv_w;
        mailbox #(axi_trans) gen2scb_w;
        mailbox #(axi_trans) mon2scb_w;
        int num_transac = 15;
        function new(virtual axi_if v);
            gen2drv = new();
            gen2scb = new();
            mon2scb = new();
            gen2drv_w = new();
            gen2scb_w = new();
            mon2scb_w = new();
            
            this.drv = new(gen2drv, gen2drv_w, v, num_transac);
            this.gen = new(gen2drv, gen2scb, gen2drv_w, gen2scb_w, num_transac);
            this.scb = new(mon2scb, gen2scb, mon2scb_w, gen2scb_w, num_transac);
            this.mon = new(mon2scb, mon2scb_w, v, num_transac);
        endfunction
        
        task run();
            fork
                gen.run_read_after_write();
                drv.run();
                scb.run();
                mon.run();
            join
            
            #200ns;
        endtask
        
        
    endclass
    
endpackage
