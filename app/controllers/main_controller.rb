class MainController < ApplicationController

  require 'net/http'

  PDB_PSSM_PATH = "/home/joan/databases/pdb_pssm/"
  PDB_PSSM_DB = PDB_PSSM_PATH+"pdb_pssm.db" 
  EBI_RES_LISTING_URL = "https://www.ebi.ac.uk/pdbe/api/pdb/entry/residue_listing/"

  def main_frame
    @pdb = params[:pdb].downcase
    @mapping = res_alignment(@pdb)
    @chains = []
    @chain_selector = []
    pdb_description  =  {}
    db = SQLite3::Database.new PDB_PSSM_DB
    db.execute( "select * from pdbsTable where pdb=\"#{@pdb.downcase}\"" ) do |r|
      pdb_description[ r[1] ] ={ 'seq_id'=>r[2] }
      db.execute( "select sequence from sequencesTable where seqId = #{r[2]};" ) do |s|
        pdb_description[ r[1] ]['seq'] = s[0]
      end
      pdb_description[ r[1] ]['status'] = [0,0]
      db.execute( "select stepNum,status from pssmsTableUniref100 where seqId = #{r[2]};" ) do |s|
        pdb_description[ r[1] ]['status'][ s[0]-2 ] = s[1]
      end
      pdb_description[ r[1] ][ 'scores' ] = [nil,nil]
      if pdb_description[ r[1] ]['status'][0] == 0
        @chains.push( r[1] )
        @chain_selector.push( [r[1],r[1]] )
        pdb_description[ r[1] ][ 'scores' ][0] = get_pssm(r[2].to_s,"2")
      end
      if pdb_description[ r[1] ]['status'][1] == 0
        pdb_description[ r[1] ][ 'scores' ][1] = get_pssm(r[2].to_s,"3")
      end
    end
    @pdb_description = pdb_description
  end
  
  def get_pssm(seq_id,n)
    file = PDB_PSSM_PATH+"/iterNum"+n+"/"+seq_id+".uniqSeq.fasta.step"+n+".pssm"
    out = [] 
    File.open( file ).each_line do |l|
      if l =~ /^(\s+)(\d)/
        r = l.split(/\s+/)
        out.push( {'index'=>r[1], 'aa'=>r[2], 'pssm'=>r[3..22], 'psfm'=>r[23..42], 'a'=>r[43], 'b'=>r[44] } )
      end
    end
    return out
  end

  def res_alignment(pdb)
    url = EBI_RES_LISTING_URL+pdb
    begin
      data = Net::HTTP.get_response(URI.parse(url)).body
    rescue
      puts "Error downloading data:\n#{$!}"
    end
    mapping = {  }
    ali = JSON.parse(data)
    ali[pdb]['molecules'].each do |m|
      m['chains'].each do |c|
        if mapping[ c['chain_id'] ].nil?
           mapping[ c['chain_id'] ] = {'align'=>[], 'inverse'=>{}}
        end
        c['residues'].each do |r|
          mapping[ c['chain_id'] ]['align'].push(r['author_residue_number'].to_i)
        end 
      end
    end
    mapping.each do |i,j|
      mapping[i]['align'] = j['align'].sort_by(&:to_i)
      n = 0
      mapping[i]['align'].each do |k|
         mapping[i]['inverse'][k]=n
         n=n+1
      end
    end
    return mapping
  end
end
