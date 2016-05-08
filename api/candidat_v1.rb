# encoding: utf-8

=begin
    democratech API synchronizes the various Web services democratech uses
    Copyright (C) 2015,2016  Thibauld Favre

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
=end

module Democratech
	class CandidatV1 < Grape::API
		version ['v1','v2']
		format :json

		get do
			# DO NOT DELETE used to test the api is live
			return {"api_version"=>"v1"}
		end

		resource :candidat do
			helpers do
				def authorized
					params['HandshakeKey']==WUFHS
				end

				def upload_image(filename)
					bucket=API.aws.bucket(AWS_BUCKET)
					key=File.basename(filename)
					obj=bucket.object(key)
					if bucket.object(key).exists? then
						STDERR.puts "#{key} already exists in S3 bucket. deleting previous object."
						obj.delete
					end
					obj.upload_file(filename, acl:'public-read')
					return key
				end
			end

			get do
				# DO NOT DELETE used to test the api is live
				return {"api_version"=>"candidat/v1"}
			end

			post 'share' do
				error!('401 Unauthorized', 401) unless authorized
				begin
					pg_connect()
					email=params["Field1"]
					candidate_id=params["Field3"]
					return if email.match(/\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/).nil?
					notifs=[]
					email=email.downcase
					message= {
						:from_name=> "LaPrimaire.org",
						:subject=> "Pour un vrai choix de candidats en 2017  !",
						:to=>[{ :email=> "email_dest" }],
						:merge_vars=>[
							{
								:vars=>[
									{
										:name=>"CANDIDATE",
										:content=>"john"
									},
									{
										:name=>"CANDIDATE_ID",
										:content=>"doe"
									},
									{
										:name=>"NB_SOUTIENS",
										:content=>"doe"
									},
								]
							}
						]
					}
					get_candidate=<<END
SELECT c.candidate_id,c.name, count(*) as nb_soutiens FROM candidates as c INNER JOIN supporters as s ON (s.candidate_id=c.candidate_id) WHERE s.candidate_id=$1 GROUP BY c.candidate_id,c.name
END
					res=API.pg.exec_params(get_candidate,[candidate_id])
				rescue
					res=nil
				ensure
					pg_close()
				end
				if not res.nil? and not res.num_tuples.zero? then
					candidate=res[0]
					msg=message
					msg[:subject]="Soutenez la candidature citoyenne de #{candidate['name']} sur LaPrimaire.org"
					msg[:to][0][:email]=email
					msg[:merge_vars][0][:rcpt]=email
					msg[:merge_vars][0][:vars][0][:content]=candidate["name"]
					msg[:merge_vars][0][:vars][1][:content]=candidate["candidate_id"]
					msg[:merge_vars][0][:vars][2][:content]=candidate["nb_soutiens"]
					begin
						result=API.mandrill.messages.send_template("laprimaire-org-support-candidate",[],msg)
						notifs.push([
							"Nouveau email de support pour #{candidate['name']} demandé !",
							"social_media",
							":email:",
							"wufoo"
						])
					rescue Mandrill::Error => e
						msg="A mandrill error occurred: #{e.class} - #{e.message}"
						notifs.push([
							"Erreur lors de l'envoi d'un email : %s" % [msg],
							"errors",
							":see_no_evil:",
							"wufoo"
						])
					end
					slack_notifications(notifs) if not notifs.empty?
				end
			end

			post 'about' do
				error!('401 Unauthorized', 401) unless authorized
				begin
					pg_connect()
					birthday=params["Field8"][0..3]+"-"+params["Field8"][4..5]+"-"+params["Field8"][6..7]
					maj={
						:birthday => birthday, #YYYY-MM-DD
						:departement => params["Field9"],
						:secteur => params["Field12"],
						:job => params["Field17"],
						:key => params["Field15"],
						:email => params["Field18"]
					}
					update_candidate=<<END
UPDATE candidates SET birthday=$1 ,departement=$2, secteur=$3, job=$4 WHERE candidate_key=$5 RETURNING *
END
					res=API.pg.exec_params(update_candidate,[maj[:birthday],maj[:departement],maj[:secteur],maj[:job],maj[:key]])
					STDERR.puts "candidate info not updated : candidate not found" if res.num_tuples.zero?
				rescue Exception=>e
					STDERR.puts "Exception raised : #{e.message}"
					res=nil
				ensure
					pg_close()
				end
			end

			post 'summary' do
				error!('401 Unauthorized', 401) unless authorized
				begin
					pg_connect()
					maj={
						:vision => params["Field1"],
						:prio1 => params["Field3"],
						:prio2 => params["Field2"],
						:prio3 => params["Field4"],
						:key => params["Field6"],
						:email => params["Field7"]
					}
					update_candidate=<<END
UPDATE candidates SET vision=$1 ,prio1=$2, prio2=$3, prio3=$4 WHERE candidate_key=$5 RETURNING *
END
					res=API.pg.exec_params(update_candidate,[maj[:vision],maj[:prio1],maj[:prio2],maj[:prio3],maj[:key]])
					STDERR.puts "candidate summary not updated : candidate not found" if res.num_tuples.zero?
				rescue Exception=>e
					STDERR.puts "Exception raised : #{e.message}"
					res=nil
				ensure
					pg_close()
				end
			end

			post 'links' do
				error!('401 Unauthorized', 401) unless authorized
				begin
					pg_connect()
					maj={
						:trello => params["Field8"],
						:website => params["Field1"],
						:facebook => params["Field2"],
						:twitter => params["Field3"],
						:linkedin => params["Field4"],
						:blog => params["Field5"],
						:instagram => params["Field6"],
						:wikipedia => params["Field7"],
						:key => params["Field9"],
						:email => params["Field11"]
					}
					update_candidate=<<END
UPDATE candidates SET trello=$1 ,website=$2, facebook=$3, twitter=$4, linkedin=$5, blog=$6, instagram=$7, wikipedia=$8 WHERE candidate_key=$9 RETURNING *
END
					res=API.pg.exec_params(update_candidate,[maj[:trello],maj[:website],maj[:facebook],maj[:twitter],maj[:linkedin],maj[:blog],maj[:instagram],maj[:wikipedia],maj[:key]])
					STDERR.puts "candidate links not updated : candidate not found" if res.num_tuples.zero?
				rescue Exception=>e
					STDERR.puts "Exception raised : #{e.message}"
					res=nil
				ensure
					pg_close()
				end
			end

			post 'photo' do
				error!('401 Unauthorized', 401) unless authorized
				begin
					pg_connect()
					maj={
						:key => params["Field3"],
						:email => params["Field4"],
						:photo_key => params["Field1"],
						:photo_url => params["Field1-url"]
					}
					get_candidate=<<END
SELECT c.candidate_id,c.candidate_key,c.name,c.photo FROM candidates as c WHERE c.candidate_key=$1
END
					res=API.pg.exec_params(get_candidate,[maj[:key]])
					raise "candidate photo not updated: candidate not found" if res.num_tuples.zero?
					candidate=res[0]
					photo=candidate['photo']
					photo="#{candidate['candidate_id']}.jpeg" if photo.nil? or photo.empty?
					upload_img=MiniMagick::Image.open(maj[:photo_url])
					upload_img.resize "x300"
					photo_path="/tmp/#{photo}"
					upload_img.write(photo_path)
					upload_image(photo_path)
				rescue Exception=>e
					STDERR.puts "Exception raised : #{e.message}"
					res=nil
				ensure
					pg_close()
				end
			end
		end
	end
end
