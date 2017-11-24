defmodule PF2AD.EWS do
  @moduledoc """
  Performs EWS calls to Microsoft Exchange and parses the XML responses.
  """

  import SweetXml
  require EEx
  require Logger

  @wgContactsFolderId Application.get_env(:pf2ad, :pf_folder_id)
  @user Application.get_env(:pf2ad, :user)
  @pw Application.get_env(:pf2ad, :password)

  EEx.function_from_file(:defp, :get_all_employees_template,
    Path.absname("./lib/templates/get_all_employees.eex"), [:assigns])

  EEx.function_from_file(:defp, :resolve_user_template,
    Path.absname("./lib/templates/resolve_user.eex"), [:assigns])

  @doc """
  Sends an EWS request to get all contacts within the configured public folder and returns the parsed response.
  """
  def get_all_employees() do
    post_request_all_contacts()
    |> parse_all_contacts_response()
  end

  @doc """
  Takes an EX500 address and returns the user's primary SMTP address.
  """
  def convert_ex_address(address) do
    post_request_resolve_email(address)
    |> parse_resolve_email()
  end


  defp post_request_all_contacts() do
    requestBody = get_all_employees_template([folderId: @wgContactsFolderId])
    headers = ["Content-Type": "text/xml"]
    options = [hackney: [basic_auth: {@user, @pw}]]
    HTTPoison.post! "https://outlook.office365.com/EWS/Exchange.asmx", requestBody, headers, options
  end


  defp parse_all_contacts_response(%{status_code: 200, body: xmlDoc}) do
    xmlDoc
    |> xpath(~x"//t:Items/t:Contact"l,
      first_name: ~x"./t:CompleteName/t:FirstName/text()"s,
      last_name: ~x"./t:CompleteName/t:LastName/text()"s,
      email_addresses: ~x"./t:EmailAddresses/t:Entry/text()"ls,
      phone_numbers: [~x"./t:PhoneNumbers/t:Entry"l,
        type: ~x"./@Key"s,
        value: ~x"./text()"s
      ],
      job_title: ~x"./t:JobTitle/text()"s
    )
  end

  defp post_request_resolve_email(user) do
    requestBody = resolve_user_template([user: user])
    headers = ["Content-Type": "text/xml"]
    options = [hackney: [basic_auth: {@user, @pw}, insecure: :true],
    #  proxy: {"localhost", 8888}]
    ]
    HTTPoison.post! "https://outlook.office365.com/EWS/Exchange.asmx", requestBody, headers, options
  end

  defp parse_resolve_email(%{status_code: 200, body: xmlDoc}) do
    xmlDoc
    |> xpath(~x"//t:Mailbox[./t:MailboxType/text()='Mailbox']/t:EmailAddress/text()"s)
  end


end
