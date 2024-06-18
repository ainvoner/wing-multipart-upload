bring cloud;
bring aws;

let api = new cloud.Api(
  cors: true,
  corsOptions: cloud.ApiCorsOptions {
    allowOrigin: "*",
    allowMethods: [cloud.HttpMethod.GET, cloud.HttpMethod.POST, cloud.HttpMethod.OPTIONS],
    allowHeaders: ["Content-Type"],
    allowCredentials: false,
    exposeHeaders: ["Content-Type"],
    maxAge: 600s
  }
);

let multipartBucket = new aws.BucketRef("bucket-c88fdc5f-20240618085816498500000001");

let handleCompleteUpload = inflight (req: cloud.ApiRequest) => {
    let json_data = Json.parse(req.body ?? "");
    let s3_key = str.fromJson(json_data["s3_key"]);
    let upload_id = str.fromJson(json_data["upload_id"]);
    let parts = num.fromJson(json_data["parts"]);
    multipartBucket.completeMultipartUpload(upload_id);
    return {
        "status": 200,
        "body": Json.stringify({
            "message": "video uploaded successfully"
        })
    };
};

let upload_video_in_parts = inflight (s3_key: str, upload_id: str, part_no: num) => {
    let signed_url = multipartBucket.signedUrl(s3_key,    
        {
            uploadId: upload_id,
            partNumber: part_no,
            action: cloud.BucketSignedUrlAction.UPLOAD
        }
    );
    log(signed_url);
    return signed_url;
};

let handleInitiateMultipartUpload = inflight (req: cloud.ApiRequest) => {
    let json_data = Json.parse(req.body ?? "");
    let s3_key = str.fromJson(json_data["s3_key"]);
    let parts = num.fromJson(json_data["parts"]);
    log("s3_key: {s3_key}");
    log("parts: {parts}");
    let upload_id: str = multipartBucket.multipartUpload(s3_key);
    log("upload_id: {upload_id}");
    let urls: MutArray<str> = MutArray<str>[];
    for i in 0..parts {
        log("uploading part {i}");
        let j = i +1;
        let url = upload_video_in_parts(s3_key, upload_id, j);
        log("url {url}");
        urls.push(url);
    }
    return {
        "status": 200,
        "body": Json.stringify({
            "upload_id": upload_id,
            "upload_urls": urls.copy()
        })
    };
};

api.post("/initiateMultipartUpload", handleInitiateMultipartUpload);
api.post("/completeUpload", handleCompleteUpload);

let website = new cloud.Website(path: "./website");
website.addJson("config.json", { apiUrl: api.url });